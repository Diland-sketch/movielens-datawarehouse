#!/usr/bin/env python3
"""Exporta las vistas de gold a CSV (y opcionalmente a Google Sheets).

Uso:
  python exportar_gold.py                  # solo CSV
  python exportar_gold.py --refrescar      # REFRESH de las vistas y luego CSV
  python exportar_gold.py --sheets         # además sube a Google Sheets
Requisitos:  pip install psycopg2-binary   (y para --sheets: pip install gspread)
"""
import argparse
import csv
import datetime as dt
import time
import decimal
import getpass
import os
import sys
from pathlib import Path

import psycopg2
from psycopg2 import sql

BASE = Path(__file__).resolve().parent
SALIDA = BASE.parent.parent / "tableau" / "datos"     # ajuste si su estructura es otra
CONSULTAS = BASE / "consultas"                        # SQL propios (ej. usuarios_segmentos.sql)
MAX_FILAS_SHEETS = 50_000

# (nombre_archivo, vista_gold | None). None => se exige consultas/<nombre>.sql (agregado, nunca por usuario)
# El orden importa para --refrescar: v_genero_resumen depende de v_genero_anio.
ENTRADAS = [
    ("peliculas_desempenio",  None),
    ("usuarios_segmentos",    None),
    ("temporalidad",          "v_temporalidad_estacionalidad"),
    ("rating_distribucion",   "v_rating_distribucion"),
    ("rating_resumen_anual",  "v_rating_resumen_anual"),
    ("genero_anio",           "v_genero_anio"),
    ("genero_resumen",        "v_genero_resumen"),
    ("genero_decada",         "v_genero_decada"),
    ("tags_top",              "v_tags_top"),
    ("tags_cobertura",        "v_tags_cobertura"),
    ("genoma_genero",         "v_genoma_genero"),
    ("genoma_correlacion",    "v_genoma_correlacion"),
]


def conectar():
    return psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "movielens_db"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD") or getpass.getpass("Contraseña de PostgreSQL: "),
    )


def refrescar(conn):
    with conn.cursor() as cur:
        for nombre, vista in ENTRADAS:
            if vista is None:
                continue
            inicio = dt.datetime.now()
            cur.execute(sql.SQL("REFRESH MATERIALIZED VIEW gold.{}").format(sql.Identifier(vista)))
            conn.commit()
            print(f"  refrescada gold.{vista} ({(dt.datetime.now() - inicio).total_seconds():.1f} s)")


def leer(conn, nombre, vista):
    with conn.cursor() as cur:
        if vista is not None:
            cur.execute(sql.SQL("SELECT * FROM gold.{}").format(sql.Identifier(vista)))
        else:
            ruta = CONSULTAS / f"{nombre}.sql"
            if not ruta.exists():
                raise FileNotFoundError(f"Falta {ruta} (consulta agregada para '{nombre}')")
            cur.execute(ruta.read_text(encoding="utf-8"))
        columnas = [d[0] for d in cur.description]
        return columnas, cur.fetchall()


def serializar(v):
    if v is None:
        return ""
    if isinstance(v, decimal.Decimal):
        return float(v)
    if isinstance(v, (dt.date, dt.datetime)):
        return v.isoformat()
    return v


def a_csv(nombre, columnas, filas):
    SALIDA.mkdir(parents=True, exist_ok=True)
    ruta = SALIDA / f"{nombre}.csv"
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(columnas)
        w.writerows([[serializar(v) for v in fila] for fila in filas])
    return ruta


def con_reintentos(fn, intentos=5, espera=3):
    from requests.exceptions import RequestException
    from gspread.exceptions import APIError
    for n in range(1, intentos + 1):
        try:
            return fn()
        except (RequestException, APIError) as e:
            if n == intentos:
                raise
            print(f"    reintento {n}/{intentos - 1} tras {type(e).__name__}")
            time.sleep(espera * n)


def a_sheets(nombre, columnas, filas):
    import gspread  # import tardío: solo se necesita con --sheets
    cred = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
    sheet_id = os.environ["SHEET_ID"]
    gc = gspread.service_account(filename=cred, http_client=gspread.BackOffHTTPClient)
    sh = con_reintentos(lambda: gc.open_by_key(sheet_id))
    try:
        ws = con_reintentos(lambda: sh.worksheet(nombre))
    except gspread.WorksheetNotFound:
        ws = con_reintentos(lambda: sh.add_worksheet(title=nombre, rows=len(filas) + 1, cols=len(columnas)))
    con_reintentos(ws.clear)
    con_reintentos(lambda: ws.resize(rows=len(filas) + 1, cols=len(columnas)))
    datos = [columnas] + [[serializar(v) for v in fila] for fila in filas]
    LOTE = 2000
    for i in range(0, len(datos), LOTE):
        lote = datos[i:i + LOTE]
        con_reintentos(lambda: ws.update(range_name=f"A{i + 1}", values=lote, value_input_option="RAW"))
        time.sleep(1)  # evita saturar la cuota de escrituras por minuto


def main():
    ap = argparse.ArgumentParser(description="Exporta vistas Gold a CSV / Google Sheets")
    ap.add_argument("--refrescar", action="store_true", help="REFRESH MATERIALIZED VIEW antes de exportar")
    ap.add_argument("--sheets", action="store_true", help="subir también a Google Sheets")
    args = ap.parse_args()

    conn = conectar()
    try:
        if args.refrescar:
            print("Refrescando vistas materializadas...")
            refrescar(conn)
        print("Exportando...")
        resumen = []
        for nombre, vista in ENTRADAS:
            try:
                columnas, filas = leer(conn, nombre, vista)
            except Exception as e:
                conn.rollback()
                print(f"  [OMITIDA] {nombre}: {e}")
                continue
            ruta = a_csv(nombre, columnas, filas)
            estado = "CSV"
            if args.sheets:
                if len(filas) > MAX_FILAS_SHEETS:
                    estado += " (Sheets omitido: demasiadas filas)"
                else:
                    try:
                        a_sheets(nombre, columnas, filas)
                        estado += " + Sheets"
                    except Exception as e:
                        estado += f" (Sheets FALLÓ: {type(e).__name__})"
                        print(f"  [SHEETS FALLÓ] {nombre}: {e}")
            resumen.append((nombre, len(filas), estado))
            print(f"  {nombre}: {len(filas)} filas -> {ruta.name}")
        print("\nResumen:")
        for n, c, e in resumen:
            print(f"  {n:<24}{c:>10}  {e}")
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())