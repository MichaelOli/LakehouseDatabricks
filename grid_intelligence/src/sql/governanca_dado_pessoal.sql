-- bronze.chamados e recriada num full refresh do pipeline, e a mascara cai junto.
-- Esta task roda depois do pipeline, em toda execucao, para reaplicar a RN-10.

USE CATALOG IDENTIFIER(:catalogo);
USE SCHEMA IDENTIFIER(:schema_bronze);

CREATE OR REPLACE FUNCTION mascara_dado_pessoal(valor STRING)
RETURN IF(is_account_group_member('atendimento'), valor, '[RESTRITO]');

ALTER TABLE chamados ALTER COLUMN nome_solicitante SET MASK mascara_dado_pessoal;
ALTER TABLE chamados ALTER COLUMN telefone_solicitante SET MASK mascara_dado_pessoal;
ALTER TABLE chamados ALTER COLUMN transcricao SET MASK mascara_dado_pessoal;
