# Pipeline de Sincronização Incremental com T-SQL

### 📋 Contexto do Problema
Sistemas escolares ou bancários sofrem com lentidão quando milhares de utilizadores tentam aceder a relatórios ou portais web ao mesmo tempo que o sistema operacional de produção está a registar novos dados. Fazer leituras completas (Full Dumps) para atualizar o portal consome muita memória e gera travamentos (locks).

### 🛠️ Solução Desenvolvida
Desenvolvi uma solução em Transact-SQL utilizando o mecanismo nativo **Change Tracking** do SQL Server. A Stored Procedure monitoriza e extrai unicamente as linhas que foram inseridas ou editadas (Operações 'I' e 'U') desde a última execução bem-sucedida.

### 🚀 Ganhos de Performance
- **Consumo de Hardware:** Redução drástica de leituras de I/O de disco no servidor operacional.
- **Concorrência:** Zero impactos de lentidão nas tabelas principais da instituição.
- **Dados em Tempo Real:** Sincronização eficaz e leve, ideal para suporte a ferramentas de analytics ou portais de utilizadores.
