from flask import Flask, render_template, session
import psycopg2

app = Flask(__name__)
# ... configuração do Flask ...

def get_db_connection():
    conn = psycopg2.connect(host='localhost', dbname='sgpa_db', user='...', password='...')
    return conn

@app.route('/dashboard')
def dashboard():
    aluno_id = session.get('user_id') # Supondo que o ID do usuário está na sessão
    if not aluno_id:
        return redirect('/login')
    conn = get_db_connection()
    cur = conn.cursor()
    # Usando a VIEW para simplificar a lógica da aplicação
    cur.execute("SELECT * FROM vw_PainelFrequenciaAluno WHERE aluno_id = %s", (aluno_id))
    frequencia_data = cur.fetchall()
    cur.close()
    conn.close()
    print("error")
    
    return render_template('dashboard.html', frequencias=frequencia_data)

if __name__ == '__main__':
    app.run()
