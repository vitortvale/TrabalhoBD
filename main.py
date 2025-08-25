import json
import psycopg2

# Configuração do banco
DB_CONFIG = {
    "dbname": "trab",
    "user": "postgres",
    "password": "newpassword",
    "host": "localhost",
    "port": 5432
}

def inserir_dados():
    # Lê o arquivo JSON
    with open("carga_inicial.json", "r", encoding="utf-8") as f:
        dados = json.load(f)

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    try:
        # --- Universidade ---
        for u in dados["Universidade"]:
            cur.execute(
                "INSERT INTO Universidade (id, nome) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (u["id"], u["nome"])
            )

            # --- Departamentos ---
            for d in u["departamentos"]:
                cur.execute(
                    "INSERT INTO Departamento (id, nome, ativo, universidade_id) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                    (d["id"], d["nome"], d["ativo"], u["id"])
                )

                # --- Cursos ---
                for c in d["cursos"]:
                    cur.execute(
                        "INSERT INTO Curso (id, nome, departamento_id) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
                        (c["id"], c["nome"], d["id"])
                    )

                    # --- Disciplinas ---
                    for disc in c["disciplinas"]:
                        cur.execute(
                            "INSERT INTO Disciplina (id, nome, codigo, carga_horaria, curso_id) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING",
                            (disc["id"], disc["nome"], disc["codigo"], disc["carga_horaria"], c["id"])
                        )

        # --- Professores ---
        for p in dados["Professores"]:
            cur.execute(
                "INSERT INTO Professor (id, nome, email) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
                (p["id"], p["nome"], p["email"])
            )

        # --- Alunos ---
        for a in dados["Alunos"]:
            cur.execute(
                "INSERT INTO Aluno (id, nome, matricula, email) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (a["id"], a["nome"], a["matricula"], a["email"])
            )

        # --- Período Letivo ---
        for pl in dados["PeriodosLetivos"]:
            cur.execute(
                "INSERT INTO PeriodoLetivo (id, codigo, inicio, fim) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (pl["id"], pl["codigo"], pl["inicio"], pl["fim"])
            )

        # --- Turmas ---
        for t in dados["Turmas"]:
            cur.execute(
                "INSERT INTO Turma (id, codigo, disciplina_id, professor_id, periodo_letivo_id) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (t["id"], t["codigo"], t["disciplina_id"], t["professor_id"], t["periodo_letivo_id"])
            )

        # --- Matrículas ---
        for m in dados["Matriculas"]:
            cur.execute(
                "INSERT INTO Matricula (id, aluno_id, turma_id, data_matricula) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (m["id"], m["aluno_id"], m["turma_id"], m["data_matricula"])
            )

        # --- Registro de Frequência ---
        for rf in dados["RegistrosFrequencia"]:
            cur.execute(
                "INSERT INTO RegistroFrequencia (id, matricula_id, data_aula, status) VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (rf["id"], rf["matricula_id"], rf["data_aula"], rf["status"])
            )

        # --- Justificativas de Falta ---
        for jf in dados["JustificativasFalta"]:
            cur.execute(
                "INSERT INTO JustificativaFalta (id, registro_frequencia_id, motivo, arquivo_path, status) VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING",
                (jf["id"], jf["registro_frequencia_id"], jf["motivo"], jf["arquivo_path"], jf["status"])
            )

        conn.commit()
        print("✅ Dados inseridos com sucesso!")

    except Exception as e:
        conn.rollback()
        print("❌ Erro ao inserir dados:", e)

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    inserir_dados()
