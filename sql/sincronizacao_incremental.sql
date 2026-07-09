-- ====================================================================================
-- STORED PROCEDURE: SP_Sincronizacao_Incremental_ChangeTracking
-- Descrição: Sincronização incremental de dados académicos e financeiros entre o 
--            Banco Transacional (OLTP) e a Base de Dados do Portal (Destino).
-- Técnica: Utilização do recurso nativo SQL Server Change Tracking.
-- Autor: Emival Miguel
-- Data: 2026
-- ====================================================================================

CREATE PROCEDURE [dbo].[SP_SINCRONIZACAO_INCREMENTAL_CHANGETRACKING]
AS
BEGIN

    SET NOCOUNT ON;




        ---------------------------------------------------
        -- VARIÁVEIS
        ---------------------------------------------------

        DECLARE @VERSAO_ATUAL BIGINT;

        DECLARE @ULTIMA_VERSAO_GUIA BIGINT;
        DECLARE @ULTIMA_VERSAO_DETALHE BIGINT;
				DECLARE @ULTIMA_VERSAO_ALUNO BIGINT;
				DECLARE @ULTIMA_VERSAO_MATRICULA BIGINT;
				DECLARE @ULTIMA_VERSAO_HISTORICO_ALUNO BIGINT;

        ---------------------------------------------------
        -- VERSÃO ATUAL DO CHANGE TRACKING
        ---------------------------------------------------
        SELECT @VERSAO_ATUAL =
            CHANGE_TRACKING_CURRENT_VERSION();
        ---------------------------------------------------
        -- OBTER ÚLTIMAS VERSÕES
        ---------------------------------------------------

        SELECT
            @ULTIMA_VERSAO_GUIA = ultima_versao
        FROM db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
        WHERE tabela = 'pagamento';

        SELECT
            @ULTIMA_VERSAO_DETALHE = ultima_versao
        FROM db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
        WHERE tabela = 'pagamento';

		SELECT 
			@ULTIMA_VERSAO_ALUNO = ULTIMA_VERSAO
		FROM db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
		WHERE TABELA = 'aluno'

		SELECT 
			@ULTIMA_VERSAO_MATRICULA = ULTIMA_VERSAO
		FROM db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
		WHERE TABELA = 't_matricula'

		SELECT 
			@ULTIMA_VERSAO_HISTORICO_ALUNO = ULTIMA_VERSAO
		FROM db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
		WHERE TABELA = 'aluno_detalhe'

      
        ---------------------------------------------------
        -- TABELA TEMP GUIA
        ---------------------------------------------------

        IF OBJECT_ID('tempdb..#GUIA_CHANGES') IS NOT NULL
            DROP TABLE #GUIA_CHANGES;

        SELECT
            CT.SYS_CHANGE_OPERATION SYS_CHANGE_OPERATION,
            F.ID,
            F.NUMERO_GUIA,
			AL.ano_lectivo ano_lectivo,
            F.data_emissao,
            F.data_vencimento,
			CASE WHEN F.anulada = 1 THEN 'ANULADA' WHEN anulada = 0 AND liquidada = 1 THEN 'PAGA' ELSE 'EMITIDA' END estado_guia,
            F.REFERENCIA,
			F.VALOR,
			F.codigo_aluno,
			F.n_factura_recibo,
			F.codigo_usuario_liquidou,
			F.data_liquidacao
        INTO #GUIA_CHANGES
        FROM CHANGETABLE
        (
            CHANGES db_producao_core.dbo.pagamento,
            @ULTIMA_VERSAO_GUIA
        ) CT
        LEFT JOIN db_producao_core.dbo.pagamento F ON F.ID = CT.ID
		LEFT JOIN db_producao_core.dbo.ano_civil AL ON F.ano_civil_id=AL.ID
            

        ---------------------------------------------------
        -- UPDATE GUIA
        ---------------------------------------------------

        UPDATE D
        SET
            D.numero_guia     = C.NUMERO_GUIA,
			D.ano_lectivo = C.ano_lectivo,
            D.data_emissao    = C.DATA_EMISSAO,
            D.data_vencimento = C.DATA_VENCIMENTO,
            D.valor           = C.VALOR,
            D.referencia      = C.REFERENCIA,
            D.estado_guia     = C.estado_guia,
			d.usuario_liquidou=c.codigo_usuario_liquidou,
			d.data_liquidacao=c.data_liquidacao
        FROM db_producao_destino.dbo.tb_GUIA D
        INNER JOIN #GUIA_CHANGES C
            ON D.ID = C.ID
        WHERE C.SYS_CHANGE_OPERATION = 'U';

        ---------------------------------------------------
        -- INSERT GUIA
        ---------------------------------------------------

        SET IDENTITY_INSERT db_producao_destino.dbo.tb_GUIA ON;

        INSERT INTO db_producao_destino.dbo.tb_GUIA
        (
            ID,
            numero_guia,
			ano_lectivo,
            data_emissao,
            data_vencimento,
			estado_guia,
			referencia,
            valor,
			aluno_id,
			numero_fatura_recibo, 
            usuario_liquidou,
			data_liquidacao
        )
        SELECT
            C.ID,
            C.NUMERO_GUIA,
			C.ano_lectivo,
            C.DATA_EMISSAO,
            C.DATA_VENCIMENTO,
			C.estado_guia,
			C.referencia,
			C.valor,
			C.codigo_aluno,
			C.n_factura_recibo,
			c.codigo_usuario_liquidou,
			c.data_liquidacao
        FROM #GUIA_CHANGES C
        WHERE C.SYS_CHANGE_OPERATION = 'I';

        SET IDENTITY_INSERT db_producao_destino.dbo.tb_GUIA OFF;



        ---------------------------------------------------
        -- TABELA TEMP DETALHE
        ---------------------------------------------------

        IF OBJECT_ID('tempdb..#DETALHE_CHANGES') IS NOT NULL
            DROP TABLE #DETALHE_CHANGES;

        SELECT
            CT.SYS_CHANGE_OPERATION SYS_CHANGE_OPERATION,
            F.ID,
            E.emolumento designacao,
            F.percentagem_iva,
            F.valor,
            F.valor_imposto,
            F.valor_total,
            F.CODIGO_GUIA_PAGAMENTO
        INTO #DETALHE_CHANGES
        FROM CHANGETABLE
        (
            CHANGES db_producao_core.dbo.pagamento,
            @ULTIMA_VERSAO_DETALHE
        ) CT
        LEFT JOIN db_producao_core.dbo.pagamento F
            ON F.ID = CT.ID
		LEFT JOIN db_producao_core.dbo.T_EMOLUMENTO E
			ON F.codigo_emolumento=E.id

        ---------------------------------------------------
        -- UPDATE DETALHE
        ---------------------------------------------------

        UPDATE D
        SET
            D.designacao      = C.DESIGNACAO,
            D.percentagem_iva = C.percentagem_iva,
            D.valor           = C.valor,
            D.valor_imposto   = C.valor_imposto,
            D.valor_total     = C.valor_total,
            D.guia_id         = C.CODIGO_GUIA_PAGAMENTO
        FROM db_producao_destino.dbo.tb_GUIA_DETALHE D
        INNER JOIN #DETALHE_CHANGES C
            ON D.ID = C.ID
        WHERE C.SYS_CHANGE_OPERATION = 'U';

        ---------------------------------------------------
        -- INSERT DETALHE
        ---------------------------------------------------

        SET IDENTITY_INSERT db_producao_destino.dbo.tb_GUIA_DETALHE ON;

        INSERT INTO db_producao_destino.dbo.tb_GUIA_DETALHE
        (
            id,
            designacao,
            percentagem_iva,
            valor,
            valor_imposto,
            valor_total,
            guia_id
        )
        SELECT
            C.ID,
            C.DESIGNACAO,
            C.percentagem_iva,
            C.valor,
            C.valor_imposto,
            C.valor_total,
            C.CODIGO_GUIA_PAGAMENTO
        FROM #DETALHE_CHANGES C
        WHERE C.SYS_CHANGE_OPERATION = 'I';

        SET IDENTITY_INSERT db_producao_destino.dbo.tb_GUIA_DETALHE OFF;

		---------------------------------------------------
        -- TABELA TEMP ALUNO
        ---------------------------------------------------
		IF OBJECT_ID('tempdb..#ALUNO_CHANGES') IS NOT NULL
			DROP TABLE #ALUNO_CHANGES;
		SELECT 
			CT.SYS_CHANGE_OPERATION SYS_CHANGE_OPERATION,
			A.ID,
			A.arquivo_identificacao,
			A.bairro,
			A.codigo_instituicao,
			A.contencioso,
			A.data_emissao_identidade, 
			A.data_nascimento,
			A.documento_indentificacao,
			A.email, A.estado_civil, 
			A.fim_curso,
			MR.descricao municipio_residencia,
			A.morada, 
			MN.descricao municipio_nascimento,
			A.necessidade_educacao_especial,
			A.NOME, A.nome_da_mae, 
			A.nome_do_pai, 
			A.numero_de_aluno, 
			A.numero_documento_identificacao,
			PN.descricao pais_nacionalidade, 
			PR.descricao pais_residencia,
			PPN.provincia provincia_nascimento, 
			PPR.provincia provincia_residencia,
			A.sexo, 
			A.telefone, 
			A.codigo_curso curso_id 
		INTO #ALUNO_CHANGES
		FROM CHANGETABLE
        (
            CHANGES db_producao_core.dbo.aluno,
            @ULTIMA_VERSAO_ALUNO
        ) CT
			LEFT JOIN db_producao_core.dbo.aluno A ON CT.ID=A.ID
			LEFT JOIN db_producao_core.dbo.t_municipio MR ON A.codigo_municio_residencia=MR.ID
			LEFT JOIN db_producao_core.dbo.t_municipio MN ON A.codigo_municipio_nascimento=MN.ID
			LEFT JOIN db_producao_core.dbo.T_PAIS PR ON A.codigo_pais_residencia=PR.id
			LEFT JOIN db_producao_core.dbo.T_PAIS PN ON A.codigo_pais_nacionalidade=PN.id
			LEFT JOIN db_producao_core.dbo.t_provincia PPN ON A.codigo_provincia_nascimento=PPN.ID
			LEFT JOIN db_producao_core.dbo.t_provincia PPR ON A.codigo_provincia_residencia=PPR.ID
		
		---------------------------------------------------
        -- UPDATE ALUNO
        ---------------------------------------------------
		UPDATE A 
			SET 
				A.contencioso=C.contencioso,
				A.data_emissao_documento=C.data_emissao_identidade,
				A.estado_civil=C.estado_civil,
				A.fim_curso=C.fim_curso,
				A.telefone=C.telefone,
				A.curso_id=C.curso_id
		FROM db_producao_destino.dbo.tb_ALUNO A
		INNER JOIN	#ALUNO_CHANGES C ON A.ID=C.id
		WHERE C.SYS_CHANGE_OPERATION = 'U'
		---------------------------------------------------
        -- INSERT ALUNO
        ---------------------------------------------------
		SET IDENTITY_INSERT db_producao_destino.dbo.tb_ALUNO ON;
		INSERT INTO db_producao_destino.dbo.tb_aluno
           (ID,
		   [arquivo_identificacao]
           ,[bairro]
           ,[codigo_instituicao]
           ,[contencioso]
           ,[data_emissao_documento]
           ,[data_nascimento]
           ,[documento_identificacao]
           ,[email]
           ,[estado_civil]
           ,[fim_curso]
           ,[municipio_residencia]
           ,[morada]
           ,[municipio_nascimento]
           ,[necessidade_educacao_especial]
           ,[nome]
           ,[nome_da_mae]
           ,[nome_do_pai]
           ,[numero_de_aluno]
           ,[numero_documento]
           ,[pais_nacionalidade]
           ,[pais_residencia]
           ,[provincia_nascimento]
           ,[provincia_residencia]
           ,[sexo]
           ,[telefone]
           ,[curso_id])
	SELECT
		ID,
		arquivo_identificacao,
		bairro,
		codigo_instituicao,
		contencioso,
		data_emissao_identidade,
		data_nascimento,
		documento_indentificacao,
		email,
		estado_civil,
		fim_curso,
		municipio_residencia,
		morada,
		municipio_nascimento,
		necessidade_educacao_especial,
		nome,
		nome_da_mae,
		nome_do_pai,
		numero_de_aluno,
		numero_documento_identificacao,
		pais_nacionalidade,
		pais_residencia,
		provincia_nascimento,
		provincia_residencia,
		sexo,
		telefone,
		curso_id
	FROM #ALUNO_CHANGES
	WHERE SYS_CHANGE_OPERATION = 'I';
	SET IDENTITY_INSERT db_producao_destino.dbo.tb_ALUNO OFF;

		 ---------------------------------------------------
        -- TEMP MATRICULA
        ---------------------------------------------------
		IF OBJECT_ID('tempdb..#MATRICULA_CHANGES') IS NOT NULL
			DROP TABLE #MATRICULA_CHANGES;
		SELECT 
			CT.SYS_CHANGE_OPERATION SYS_CHANGE_OPERATION,
			M.ID, 
			M.ano_curricular, 
			M.ano_lectivo, 
			M.crescimento_propina,
			CAST (I.descricao AS varchar(255)) tipo_inscricao, 
			T.turno, 
			M.codigo_aluno aluno_id
		INTO #MATRICULA_CHANGES
		FROM CHANGETABLE
        (
            CHANGES db_producao_core.dbo.t_matricula,
            @ULTIMA_VERSAO_MATRICULA
        ) CT
			LEFT JOIN db_producao_core.dbo.t_matricula M ON CT.ID=M.ID
			LEFT JOIN db_producao_core.dbo.t_tipo_inscricao I ON M.codigo_tipo_inscricao=I.id
			LEFT JOIN db_producao_core.dbo.t_turma T ON M.codigo_turma_base=T.id
		---------------------------------------------------
        -- UPDATE MATRICULA
        ---------------------------------------------------
		UPDATE M 
		SET
			M.ano_curricular=C.ano_curricular,
			M.crescimento_propina=C.crescimento_propina,
			M.tipo_inscricao=C.tipo_inscricao,
			M.turno=C.turno
		FROM db_producao_destino.dbo.tb_matricula M 
		INNER JOIN #MATRICULA_CHANGES C 
			ON M.ID=C.id
		WHERE C.SYS_CHANGE_OPERATION = 'U';
		---------------------------------------------------
        -- INSERT MATRICULA
        ---------------------------------------------------
		SET IDENTITY_INSERT db_producao_destino.dbo.tb_MATRICULA ON;
		INSERT INTO db_producao_destino.dbo.tb_matricula
           (ID, 
		   [ano_curricular]
           ,[ano_lectivo]
           ,[crescimento_propina]
           ,[tipo_inscricao]
           ,[turno]
           ,[aluno_id])
		   SELECT C.ID, 
			C.ano_curricular, 
			C.ano_lectivo, 
			C.crescimento_propina, 
			C.tipo_inscricao,
			C.turno, 
			C.aluno_id
		   FROM #MATRICULA_CHANGES C
		   WHERE C.SYS_CHANGE_OPERATION = 'I';
		   SET IDENTITY_INSERT db_producao_destino.dbo.tb_MATRICULA OFF;
		---------------------------------------------------
        -- TEMP HISTORICO
        ---------------------------------------------------
		 IF OBJECT_ID('tempdb..#HISTORICO_ALUNO_CHANGES') IS NOT NULL
            DROP TABLE #HISTORICO_ALUNO_CHANGES

        SELECT
            CT.SYS_CHANGE_OPERATION SYS_CHANGE_OPERATION,
			A.id, 
			AL.ano_lectivo ano_lectivo,
			D.descricao disciplina,
			A.nota_final media_final, A.codigo_matricula matricula_id,
			A.validada, A.nota_final_continua, 
			A.primeira_frequencia, A.segunda_frequencia, A.terceira_frequencia, A.quarta_frequencia,
			A.nota_pratica, A.nota_exame, A.nota_exame_oral, A.nota_recurso,
			A.nota_recurso_oral            
        INTO #HISTORICO_ALUNO_CHANGES
        FROM CHANGETABLE
        (
            CHANGES db_producao_core.dbo.aluno_detalhe,
            @ULTIMA_VERSAO_HISTORICO_ALUNO
        ) CT
        LEFT JOIN db_producao_core.dbo.aluno_detalhe A ON CT.ID=A.ID
		LEFT JOIN db_producao_core.dbo.t_disciplina D ON A.codigo_disciplina=D.id
		LEFT JOIN db_producao_core.dbo.ano_civil AL ON A.ano_civil_id=AL.ID
		---------------------------------------------------
        -- UPDATE HISTORICO
        ---------------------------------------------------
		UPDATE A 
			SET
				A.media_final=C.media_final,
				A.validada=C.validada,
				A.nota_final_continua=C.nota_final_continua,
				A.primeira_frequencia=C.primeira_frequencia,
				A.segunda_frequencia=C.segunda_frequencia,
				A.terceira_frequencia=c.terceira_frequencia,
				a.quarta_frequencia=C.quarta_frequencia,
				A.nota_pratica=C.nota_pratica,
				A.nota_exame=C.nota_exame,
				A.nota_exame_oral=C.nota_exame_oral,
				A.nota_recurso=C.nota_recurso,
				A.nota_recurso_oral=C.nota_recurso_oral
		FROM db_producao_destino.dbo.tb_historico_academico A
		INNER JOIN #HISTORICO_ALUNO_CHANGES C ON A.ID=C.id
		WHERE C.SYS_CHANGE_OPERATION = 'U'

		---------------------------------------------------
        -- INSERT HISTORICO
        ---------------------------------------------------
		SET IDENTITY_INSERT db_producao_destino.dbo.tb_HISTORICO_ACADEMICO ON;
		INSERT INTO db_producao_destino.dbo.tb_historico_academico
           (
		   ID, 
		   [ano_lectivo]
           ,[disciplina]
           ,[media_final]
           ,[matricula_id]
           ,[validada]
           ,[nota_final_continua]
           ,[primeira_frequencia]
           ,[segunda_frequencia]
           ,[terceira_frequencia]
           ,[quarta_frequencia]
           ,[nota_pratica]
           ,[nota_exame]
           ,[nota_exame_oral]
           ,[nota_recurso]
           ,[nota_recurso_oral])
		SELECT ID, 
		   [ano_lectivo]
           ,[disciplina]
           ,[media_final]
           ,[matricula_id]
           ,[validada]
           ,[nota_final_continua]
           ,[primeira_frequencia]
           ,[segunda_frequencia]
           ,[terceira_frequencia]
           ,[quarta_frequencia]
           ,[nota_pratica]
           ,[nota_exame]
           ,[nota_exame_oral]
           ,[nota_recurso]
           ,[nota_recurso_oral]
		FROM #HISTORICO_ALUNO_CHANGES c
		WHERE c.SYS_CHANGE_OPERATION = 'I';
		SET IDENTITY_INSERT db_producao_destino.dbo.tb_HISTORICO_ACADEMICO OFF;

        ---------------------------------------------------
        -- ATUALIZAR VERSÕES
        ---------------------------------------------------
	IF EXISTS (SELECT 1 FROM #GUIA_CHANGES)
		BEGIN
			UPDATE t_controle_sicronizacao_portal_aluno
			SET ultima_versao = @VERSAO_ATUAL
			WHERE tabela = 'pagamento';
		END
	IF EXISTS (SELECT 1 FROM #DETALHE_CHANGES)
		BEGIN
				UPDATE t_controle_sicronizacao_portal_aluno
				SET ultima_versao = @VERSAO_ATUAL
				WHERE tabela = 'pagamento';
		END
	IF EXISTS (SELECT 1 FROM #ALUNO_CHANGES)
		BEGIN
				UPDATE db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
				SET ultima_versao = @VERSAO_ATUAL
				WHERE tabela = 'aluno';
		END
	IF EXISTS (SELECT 1 FROM #MATRICULA_CHANGES)
		BEGIN
				UPDATE db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
				SET ultima_versao = @VERSAO_ATUAL
				WHERE tabela = 't_matricula';
		END
	IF EXISTS (SELECT 1 FROM #HISTORICO_ALUNO_CHANGES)
		BEGIN
				UPDATE db_producao_core.dbo.t_controle_sicronizacao_portal_aluno
				SET ultima_versao = @VERSAO_ATUAL
				WHERE tabela = 'aluno_detalhe';
		END

END;
