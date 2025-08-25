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
-- 1. Carga da Estrutura Acadêmica
-- ===============================
-- Universidade
INSERT INTO Universidade (id, nome) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Universidade Federal de Juiz de Fora');

-- Departamentos
INSERT INTO Departamento (id, nome, ativo, universidade_id) VALUES
    ('22222222-2222-2222-2222-222222222222', 'Departamento de Ciência da Computação', true, '11111111-1111-1111-1111-111111111111'),
    ('22222222-2222-2222-2222-222222222223', 'Departamento de Engenharia Elétrica', true, '11111111-1111-1111-1111-111111111111');

-- Cursos
INSERT INTO Curso (id, nome, departamento_id) VALUES
    ('33333333-3333-3333-3333-333333333333', 'Bacharelado em Ciência da Computação', '22222222-2222-2222-2222-222222222222'),
    ('33333333-3333-3333-3333-333333333334', 'Engenharia Elétrica', '22222222-2222-2222-2222-222222222223');

-- Disciplinas
INSERT INTO Disciplina (id, nome, codigo, carga_horaria, curso_id) VALUES
    ('44444444-4444-4444-4444-444444444444', 'Banco de Dados I', 'INF1001', 60, '33333333-3333-3333-3333-333333333333'),
    ('44444444-4444-4444-4444-444444444445', 'Estruturas de Dados', 'INF1002', 60, '33333333-3333-3333-3333-333333333333'),
    ('44444444-4444-4444-4444-444444444446', 'Circuitos Elétricos', 'ELE2001', 60, '33333333-3333-3333-3333-333333333334');

-- Professores
INSERT INTO Professor (id, nome, email) VALUES
    ('55555555-5555-5555-5555-555555555555', 'Dr. Carlos Almeida', 'carlos.almeida@ufjf.edu.br'),
    ('55555555-5555-5555-5555-555555555556', 'Dra. Fernanda Souza', 'fernanda.souza@ufjf.edu.br');

-- Alunos
INSERT INTO Aluno (id, nome, matricula, email) VALUES
    ('66666666-6666-6666-6666-666666666666', 'João Silva', '20250001', 'joao.silva@estudante.ufjf.br'),
    ('66666666-6666-6666-6666-666666666667', 'Maria Oliveira', '20250002', 'maria.oliveira@estudante.ufjf.br'),
    ('66666666-6666-6666-6666-666666666668', 'Pedro Santos', '20250003', 'pedro.santos@estudante.ufjf.br');

-- Período Letivo
INSERT INTO PeriodoLetivo (id, codigo, inicio, fim) VALUES
    ('77777777-7777-7777-7777-777777777777', '2025.1', '2025-03-01', '2025-07-15');

-- Turmas
INSERT INTO Turma (id, codigo, disciplina_id, professor_id, periodo_letivo_id) VALUES
    ('88888888-8888-8888-8888-888888888888', 'INF1001-T01', '44444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', '77777777-7777-7777-7777-777777777777'),
    ('88888888-8888-8888-8888-888888888889', 'INF1002-T01', '44444444-4444-4444-4444-444444444445', '55555555-5555-5555-5555-555555555556', '77777777-7777-7777-7777-777777777777');

-- Matrículas
INSERT INTO Matricula (id, aluno_id, turma_id, data_matricula) VALUES
    ('99999999-9999-9999-9999-999999999991', '66666666-6666-6666-6666-666666666666', '88888888-8888-8888-8888-888888888888', '2025-02-20'),
    ('99999999-9999-9999-9999-999999999992', '66666666-6666-6666-6666-666666666667', '88888888-8888-8888-8888-888888888888', '2025-02-20'),
    ('99999999-9999-9999-9999-999999999993', '66666666-6666-6666-6666-666666666668', '88888888-8888-8888-8888-888888888889', '2025-02-21');

-- Registro de Frequência
INSERT INTO RegistroFrequencia (id, matricula_id, data_aula, status, data_lancamento) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '99999999-9999-9999-9999-999999999991', '2025-03-05', 'Presente', NOW()),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', '99999999-9999-9999-9999-999999999992', '2025-03-05', 'Faltou', NOW()),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3', '99999999-9999-9999-9999-999999999993', '2025-03-06', 'Faltou', NOW());

-- Justificativa de Falta
INSERT INTO JustificativaFalta (id, registro_frequencia_id, motivo, arquivo_path, data_envio, status) VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'Estava doente, com atestado médico', '/uploads/justificativas/atestado_maria.pdf', NOW(), 'Pendente'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3', 'Problema de transporte público', NULL, NOW(), 'Pendente');
