import psycopg2
import pandas as pd
import connect
from sqlalchemy import create_engine, text

uri = f"postgres+psycopg2://{connect.user}:{connect:pwd}@{connect.host}:5432/{connect.db}"

engine = create_engine(uri)

conn = engine.connect()


query1 = """
SELECT
    u.nome_completo AS nome_aluno,
    a.matricula,
    rf.status
FROM
    Matricula m
JOIN
    Aluno a ON m.aluno_id = a.usuario_id
JOIN
    Usuario u ON a.usuario_id = u.id
LEFT JOIN
    RegistroFrequencia rf ON m.id = rf.matricula_id AND rf.data_aula = :data_aula
WHERE
    m.turma_id = :turma_id
ORDER BY
    u.nome_completo;
"""

query2 = """
-- Parâmetros: :turma_id (UUID da turma), :data_aula (Data da aula no formato 'YYYY-MM-DD')
WITH FrequenciaPorDisciplina AS (
    SELECT
        d.nome AS disciplina,
        t.codigo AS turma,
        p.nome_completo AS professor,
        COUNT(rf.id) AS total_aulas_registradas,
        COUNT(rf.id) FILTER (WHERE rf.status = 'Faltou') AS total_faltas
    FROM
        Matricula m
    JOIN
        Aluno a ON m.aluno_id = a.usuario_id
    JOIN
        Turma t ON m.turma_id = t.id
    JOIN
        Disciplina d ON t.disciplina_id = d.id
    JOIN
        Professor prof_spec ON t.professor_id = prof_spec.usuario_id
    JOIN
        Usuario p ON prof_spec.usuario_id = p.id
    LEFT JOIN
        RegistroFrequencia rf ON m.id = rf.matricula_id
    WHERE
        a.usuario_id = :aluno_usuario_id
    GROUP BY
        d.nome, t.codigo, p.nome_completo
)
SELECT
    disciplina,
    turma,
    professor,
    total_aulas_registradas,
    total_faltas,
    -- Calcula o percentual de frequência, tratando a divisão por zero
    CASE
        WHEN total_aulas_registradas > 0 THEN
            ROUND(((total_aulas_registradas - total_faltas)::DECIMAL / total_aulas_registradas) * 100, 2)
        ELSE
            100.00
    END AS percentual_frequencia
FROM
    FrequenciaPorDisciplina
ORDER BY
    disciplina;
"""

query3 = """
-- Parâmetro: :depto_id (UUID do departamento)
SELECT
    d.nome AS disciplina,
    t.codigo AS turma,
    p.nome_completo AS professor,
    COUNT(DISTINCT m.aluno_id) AS total_alunos,
    COUNT(rf.id) AS total_lancamentos,
    -- Calcula a taxa de ausência média da turma
    CASE
        WHEN COUNT(rf.id) > 0 THEN
            ROUND((COUNT(rf.id) FILTER (WHERE rf.status = 'Faltou'))::DECIMAL / COUNT(rf.id) * 100, 2)
        ELSE
            0.00
    END AS taxa_de_ausencia_percentual
FROM
    Turma t
JOIN
    Disciplina d ON t.disciplina_id = d.id
JOIN
    Curso c ON d.curso_id = c.id
JOIN
    Professor prof_spec ON t.professor_id = prof_spec.usuario_id
JOIN
    Usuario p ON prof_spec.usuario_id = p.id
JOIN
    Matricula m ON t.id = m.turma_id
LEFT JOIN
    RegistroFrequencia rf ON m.id = rf.matricula_id
WHERE
    c.departamento_id = :depto_id
GROUP BY
    d.nome, t.codigo, p.nome_completo
ORDER BY
    taxa_de_ausencia_percentual DESC, disciplina;
"""

params1 = {
    'turma_id': '1', 
    'data_aula': '2025-03-18'   
}

params2 = {
    'turma_id': '1',
    'data_aula': '2025-03-18'
}

params3 = {
    "depto_id": '1'
}
df1 = pd.read_sql(sql=text(query1), con=conn, params=params1)
df2 = pd.read_sql(sql=text(query2), con=conn, params=params2)
df3 = pd.read_sql(sql=text(query3), con=conn, params=params3)

print(df1.head())
print(df2.head())
print(df3.head())

