-- A mascara da RN-10 vale para quem consulta. O pipeline tambem consulta,
-- e com ela ligada leria [RESTRITO] no lugar da transcricao.
-- Esta task devolve o texto original so enquanto o pipeline roda.
-- A task de governanca, depois, recoloca a mascara.

USE CATALOG IDENTIFIER(:catalogo);
USE SCHEMA IDENTIFIER(:schema_bronze);

CREATE OR REPLACE FUNCTION leitura_interna(valor STRING)
RETURN valor;

ALTER TABLE chamados ALTER COLUMN nome_solicitante SET MASK leitura_interna;
ALTER TABLE chamados ALTER COLUMN telefone_solicitante SET MASK leitura_interna;
ALTER TABLE chamados ALTER COLUMN transcricao SET MASK leitura_interna;
