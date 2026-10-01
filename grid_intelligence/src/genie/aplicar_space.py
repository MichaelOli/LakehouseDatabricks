"""Cria ou atualiza o Genie space a partir do JSON versionado.

O catalogo entra so na hora de aplicar. O arquivo space.json guarda ${catalogo}.
"""

import json
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
MODELO = RAIZ / "space.json"
ARQUIVO_ID = RAIZ / "space_id"
PERFIL = "grid_intelligence"
WAREHOUSE = "1d496deecacf10fd"
TITULO = "Grid Intelligence"


def main() -> None:
    catalogo = sys.argv[1] if len(sys.argv) > 1 else "grid_dev"
    payload = MODELO.read_text(encoding="utf-8").replace("${catalogo}", catalogo)
    json.loads(payload)
    space_id = ARQUIVO_ID.read_text(encoding="utf-8").strip() if ARQUIVO_ID.exists() else ""
    if space_id:
        comando = [
            "databricks",
            "genie",
            "update-space",
            space_id,
            "--serialized-space",
            payload,
            "--warehouse-id",
            WAREHOUSE,
            "--title",
            TITULO,
            "--profile",
            PERFIL,
            "-o",
            "json",
        ]
    else:
        comando = [
            "databricks",
            "genie",
            "create-space",
            WAREHOUSE,
            payload,
            "--title",
            TITULO,
            "--description",
            "Perguntas sobre a operacao da Luz do Vale, somente na gold.",
            "--profile",
            PERFIL,
            "-o",
            "json",
        ]
    resultado = subprocess.run(comando, check=True, capture_output=True, text=True)
    print(resultado.stdout)
    if not space_id:
        criado = json.loads(resultado.stdout)
        ARQUIVO_ID.write_text(criado["space_id"] + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
