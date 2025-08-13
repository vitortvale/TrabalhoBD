-- Tipos Enumerados para Status
CREATE TYPE status_frequencia AS ENUM ('Presente', 'Faltou');
CREATE TYPE status_justificativa AS ENUM ('Pendente', 'Aprovada', 'Rejeitada');

-- Tabelas da Estrutura Acadêmica
CREATE TABLE Universidade (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL
);

CREATE TABLE Departamento (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    ativo BOOLEAN DEFAULT true,
    universidade_id UUID NOT NULL REFERENCES Universidade(id) ON DELETE RESTRICT
);

CREATE TABLE Curso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    departamento_id UUID NOT NULL REFERENCES Departamento(id) ON DELETE RESTRICT
);

CREATE TABLE Disciplina (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    carga_horaria INT NOT NULL,
    curso_id UUID NOT NULL REFERENCES Curso(id) ON DELETE RESTRICT
);

-- Tabelas de Usuários e Contexto de Turma
CREATE TABLE Professor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE Aluno (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    matricula VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE PeriodoLetivo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo VARCHAR(20) UNIQUE NOT NULL, -- Ex: "2025.1"
    inicio DATE NOT NULL,
    fim DATE NOT NULL
);

CREATE TABLE Turma (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo VARCHAR(50) NOT NULL,
    disciplina_id UUID NOT NULL REFERENCES Disciplina(id) ON DELETE RESTRICT,
    professor_id UUID NOT NULL REFERENCES Professor(id) ON DELETE RESTRICT,
    periodo_letivo_id UUID NOT NULL REFERENCES PeriodoLetivo(id) ON DELETE RESTRICT
);

CREATE TABLE Matricula (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aluno_id UUID NOT NULL REFERENCES Aluno(id) ON DELETE CASCADE, -- Aluno sai, matrícula some
    turma_id UUID NOT NULL REFERENCES Turma(id) ON DELETE RESTRICT, -- Turma não pode ser deletada se tiver matrícula
    data_matricula DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE(aluno_id, turma_id)
);

-- Tabelas de Negócio Principal (Presença)
CREATE TABLE RegistroFrequencia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    matricula_id UUID NOT NULL REFERENCES Matricula(id) ON DELETE RESTRICT,
    data_aula DATE NOT NULL,
    status status_frequencia NOT NULL,
    data_lancamento TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(matricula_id, data_aula)
);

CREATE TABLE JustificativaFalta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registro_frequencia_id UUID UNIQUE NOT NULL REFERENCES RegistroFrequencia(id) ON DELETE CASCADE,
    motivo TEXT,
    arquivo_path VARCHAR(512), -- Caminho para o arquivo no S3, por exemplo [cite: 53]
    data_envio TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status status_justificativa DEFAULT 'Pendente'
);

-- SCRIPT DE CARGA DE DADOS PARA O SISTEMA SGPA
-- OBS: Este script deve ser executado em sua totalidade.

DO $$
DECLARE
    -- Variáveis para armazenar os IDs gerados
    v_universidade_id UUID;
    v_dcc_id UUID; -- Depto de Ciência da Computação
    v_depto_eng_id UUID;
    v_curso_cc_id UUID; -- Curso de Ciência da Computação
    v_curso_si_id UUID;
    v_curso_es_id UUID;
    v_disc_bd_id UUID; -- Disciplina de Banco de Dados
    v_disc_aed_id UUID;
    v_disc_es_id UUID;
    v_disc_rc_id UUID;
    v_periodo_id UUID;
    
    -- IDs de Usuários
    v_admin_id UUID;
    v_chefe_dpto_id UUID;
    v_prof_maria_id UUID;
    v_prof_carlos_id UUID;
    v_aluno_joao_id UUID;
    v_aluno_ana_id UUID;
    v_aluno_bruno_id UUID;
    v_aluno_carla_id UUID;

    -- IDs de Turmas
    v_turma_bd_id UUID;
    v_turma_aed_id UUID;
    v_turma_es_id UUID;

    -- IDs de Matrículas
    v_mat_joao_bd_id UUID;
    v_mat_ana_bd_id UUID;
    v_mat_bruno_aed_id UUID;
    v_mat_carla_aed_id UUID;
    v_mat_joao_es_id UUID;
    v_mat_carla_es_id UUID;

    -- IDs de Frequência
    v_falta_joao_bd_id UUID;
    v_falta_bruno_aed_id UUID;

BEGIN

-- 1. Carga da Estrutura Acadêmica
-- ===============================

INSERT INTO Universidade (nome) VALUES ('Universidade Federal de Juiz de Fora') RETURNING id INTO v_universidade_id;

INSERT INTO Departamento (nome, universidade_id) VALUES 
    ('Departamento de Ciência da Computação', v_universidade_id),
    ('Departamento de Engenharia', v_universidade_id)
RETURNING id, id INTO v_dcc_id, v_depto_eng_id; -- Armazena apenas o primeiro ID em v_dcc_id

-- Ajuste para pegar o segundo ID para o depto de engenharia (uma limitação do RETURNING simples)
SELECT id INTO v_depto_eng_id FROM Departamento WHERE nome = 'Departamento de Engenharia';

INSERT INTO Curso (nome, departamento_id) VALUES
    ('Ciência da Computação', v_dcc_id),
    ('Sistemas de Informação', v_dcc_id),
    ('Engenharia de Software', v_dcc_id)
RETURNING id, id, id INTO v_curso_cc_id, v_curso_si_id, v_curso_es_id;
SELECT id INTO v_curso_si_id FROM Curso WHERE nome = 'Sistemas de Informação';
SELECT id INTO v_curso_es_id FROM Curso WHERE nome = 'Engenharia de Software';

INSERT INTO Disciplina (nome, codigo, carga_horaria, curso_id) VALUES
    ('Banco de Dados', 'DCC060', 60, v_curso_cc_id),
    ('Algoritmos e Estruturas de Dados', 'DCC007', 90, v_curso_cc_id),
    ('Engenharia de Software I', 'DCC061', 60, v_curso_es_id),
    ('Redes de Computadores', 'DCC062', 60, v_curso_cc_id)
RETURNING id, id, id, id INTO v_disc_bd_id, v_disc_aed_id, v_disc_es_id, v_disc_rc_id;
SELECT id INTO v_disc_aed_id FROM Disciplina WHERE codigo = 'DCC007';
SELECT id INTO v_disc_es_id FROM Disciplina WHERE codigo = 'DCC061';
SELECT id INTO v_disc_rc_id FROM Disciplina WHERE codigo = 'DCC062';

-- 2. Carga de Período Letivo
-- =========================
INSERT INTO PeriodoLetivo (codigo, inicio, fim) VALUES ('2025.1', '2025-03-03', '2025-07-15') RETURNING id INTO v_periodo_id;

-- 3. Carga de Usuários e Perfis
-- =============================
-- Senha para todos: 'senha123' (hash gerado para 'senha123' com bcrypt)
INSERT INTO Usuario (nome_completo, email, senha_hash, perfil, ativo) VALUES
    ('Admin do Sistema', 'admin@ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'ADMINISTRADOR', true),
    ('Roberto Diretor', 'roberto.chefe@ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'CHEFE_DEPARTAMENTO', true),
    ('Prof. Maria Santos', 'maria.santos@ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'PROFESSOR', true),
    ('Prof. Carlos Lima', 'carlos.lima@ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'PROFESSOR', true),
    ('João da Silva', 'joao.silva@aluno.ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'ALUNO', true),
    ('Ana Pereira', 'ana.pereira@aluno.ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'ALUNO', true),
    ('Bruno Costa', 'bruno.costa@aluno.ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'ALUNO', true),
    ('Carla Oliveira', 'carla.oliveira@aluno.ufjf.br', '$2a$10$vKiR9w23e.y3gJ4s2qjNPe/d8dBlh6b7iWz6V4TMgD7dJ5.qG2f/a', 'ALUNO', true)
RETURNING id, id, id, id, id, id, id, id INTO v_admin_id, v_chefe_dpto_id, v_prof_maria_id, v_prof_carlos_id, v_aluno_joao_id, v_aluno_ana_id, v_aluno_bruno_id, v_aluno_carla_id;

-- Seleções para garantir que as variáveis corretas sejam atribuídas
SELECT id INTO v_chefe_dpto_id FROM Usuario WHERE email = 'roberto.chefe@ufjf.br';
SELECT id INTO v_prof_maria_id FROM Usuario WHERE email = 'maria.santos@ufjf.br';
SELECT id INTO v_prof_carlos_id FROM Usuario WHERE email = 'carlos.lima@ufjf.br';
SELECT id INTO v_aluno_joao_id FROM Usuario WHERE email = 'joao.silva@aluno.ufjf.br';
SELECT id INTO v_aluno_ana_id FROM Usuario WHERE email = 'ana.pereira@aluno.ufjf.br';
SELECT id INTO v_aluno_bruno_id FROM Usuario WHERE email = 'bruno.costa@aluno.ufjf.br';
SELECT id INTO v_aluno_carla_id FROM Usuario WHERE email = 'carla.oliveira@aluno.ufjf.br';

-- Especialização dos Professores
INSERT INTO Professor (usuario_id, departamento_id) VALUES
    (v_prof_maria_id, v_dcc_id),
    (v_prof_carlos_id, v_dcc_id);

-- Especialização dos Alunos
INSERT INTO Aluno (usuario_id, matricula, curso_id) VALUES
    (v_aluno_joao_id, '2021001', v_curso_cc_id),
    (v_aluno_ana_id, '2021002', v_curso_si_id),
    (v_aluno_bruno_id, '2021003', v_curso_cc_id),
    (v_aluno_carla_id, '2021004', v_curso_es_id);

-- 4. Carga de Turmas
-- ===================
INSERT INTO Turma (codigo, dias_semana, horario, disciplina_id, professor_id, periodo_letivo_id) VALUES
    ('T1', 'Terça, Quinta', '10:00 - 12:00', v_disc_bd_id, v_prof_maria_id, v_periodo_id),
    ('T1', 'Segunda, Quarta, Sexta', '08:00 - 10:00', v_disc_aed_id, v_prof_carlos_id, v_periodo_id),
    ('T1', 'Segunda, Quarta', '14:00 - 16:00', v_disc_es_id, v_prof_maria_id, v_periodo_id)
RETURNING id, id, id INTO v_turma_bd_id, v_turma_aed_id, v_turma_es_id;

SELECT id INTO v_turma_aed_id FROM Turma WHERE disciplina_id = v_disc_aed_id;
SELECT id INTO v_turma_es_id FROM Turma WHERE disciplina_id = v_disc_es_id;

-- 5. Carga de Matrículas
-- ======================
INSERT INTO Matricula (aluno_id, turma_id, data_matricula) VALUES
    (v_aluno_joao_id, v_turma_bd_id, '2025-03-01'),
    (v_aluno_ana_id, v_turma_bd_id, '2025-03-01'),
    (v_aluno_bruno_id, v_turma_aed_id, '2025-03-01'),
    (v_aluno_carla_id, v_turma_aed_id, '2025-03-01'),
    (v_aluno_joao_id, v_turma_es_id, '2025-03-02'),
    (v_aluno_carla_id, v_turma_es_id, '2025-03-02')
RETURNING id, id, id, id, id, id INTO v_mat_joao_bd_id, v_mat_ana_bd_id, v_mat_bruno_aed_id, v_mat_carla_aed_id, v_mat_joao_es_id, v_mat_carla_es_id;

-- Seleções para garantir as variáveis corretas
SELECT id INTO v_mat_ana_bd_id FROM Matricula WHERE aluno_id = v_aluno_ana_id AND turma_id = v_turma_bd_id;
SELECT id INTO v_mat_bruno_aed_id FROM Matricula WHERE aluno_id = v_aluno_bruno_id AND turma_id = v_turma_aed_id;
SELECT id INTO v_mat_carla_aed_id FROM Matricula WHERE aluno_id = v_aluno_carla_id AND turma_id = v_turma_aed_id;
SELECT id INTO v_mat_joao_es_id FROM Matricula WHERE aluno_id = v_aluno_joao_id AND turma_id = v_turma_es_id;
SELECT id INTO v_mat_carla_es_id FROM Matricula WHERE aluno_id = v_aluno_carla_id AND turma_id = v_turma_es_id;


-- 6. Carga de Frequências
-- =========================
-- Aluno João na turma de Banco de Dados
INSERT INTO RegistroFrequencia (matricula_id, data_aula, status) VALUES
    (v_mat_joao_bd_id, '2025-03-11', 'Presente'),
    (v_mat_joao_bd_id, '2025-03-13', 'Presente'),
    (v_mat_joao_bd_id, '2025-03-18', 'Faltou');
SELECT id INTO v_falta_joao_bd_id FROM RegistroFrequencia WHERE matricula_id = v_mat_joao_bd_id AND data_aula = '2025-03-18';

-- Aluno Bruno na turma de Algoritmos
INSERT INTO RegistroFrequencia (matricula_id, data_aula, status) VALUES
    (v_mat_bruno_aed_id, '2025-03-10', 'Presente'),
    (v_mat_bruno_aed_id, '2025-03-12', 'Presente'),
    (v_mat_bruno_aed_id, '2025-03-14', 'Faltou'),
    (v_mat_bruno_aed_id, '2025-03-17', 'Faltou');
SELECT id INTO v_falta_bruno_aed_id FROM RegistroFrequencia WHERE matricula_id = v_mat_bruno_aed_id AND data_aula = '2025-03-17';

-- Aluna Ana na turma de Banco de Dados (só presenças)
INSERT INTO RegistroFrequencia (matricula_id, data_aula, status) VALUES
    (v_mat_ana_bd_id, '2025-03-11', 'Presente'),
    (v_mat_ana_bd_id, '2025-03-13', 'Presente');

-- 7. Carga de Justificativas
-- ==========================
INSERT INTO JustificativaFalta (registro_frequencia_id, motivo, arquivo_path, status) VALUES
    (v_falta_joao_bd_id, 'Consulta médica', '/anexos/atestado_joao.pdf', 'Pendente'),
    (v_falta_bruno_aed_id, 'Problema familiar', '/anexos/declaracao_bruno.pdf', 'Aprovada');

END $$;