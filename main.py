#!/usr/bin/env python3
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from datetime import date, timedelta
from typing import List, Dict
import uuid
import os

# =========================
# App
# =========================
app = FastAPI(title="Yo Estudio App")

# =========================
# CORS (NECESARIO PARA FLUTTER WEB)
# =========================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # luego se puede restringir
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# Configuración básica
# =========================
UPLOAD_DIR = "comprobantes"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# =========================
# Helpers
# =========================
def generar_4_sabados(fecha_inicio: str) -> List[str]:
    y, m, d = map(int, fecha_inicio.split("-"))
    inicio = date(y, m, d)
    return [(inicio + timedelta(days=7 * i)).isoformat() for i in range(4)]

# =========================
# Datos en memoria (MVP)
# =========================
GRUPOS: List[Dict] = [
    {
        "id": "ucr_una_1_3",
        "curso": "Admisión UCR–UNA",
        "inicio": "2026-02-14",
        "horario": "1:00 p.m. – 3:00 p.m.",
        "cupos_max": 6,
        "cupos_ocupados": 0,
    },
    {
        "id": "ucr_una_tec_10_12",
        "curso": "Admisión UCR–UNA–TEC",
        "inicio": "2026-02-14",
        "horario": "10:00 a.m. – 12:00 m.d.",
        "cupos_max": 6,
        "cupos_ocupados": 0,
    },
    {
        "id": "ucr_una_tec_3_5",
        "curso": "Admisión UCR–UNA–TEC",
        "inicio": "2026-02-14",
        "horario": "3:00 p.m. – 5:00 p.m.",
        "cupos_max": 6,
        "cupos_ocupados": 0,
    },
]

MATRICULAS: Dict[str, Dict] = {}

# =========================
# Endpoints públicos
# =========================
@app.get("/")
def home():
    return {"ok": True, "app": "Yo Estudio"}

@app.get("/grupos")
def listar_grupos():
    return [
        {
            **g,
            "cupos_disponibles": g["cupos_max"] - g["cupos_ocupados"],
        }
        for g in GRUPOS
    ]

@app.post("/matricula")
async def solicitar_matricula(
    estudiante: str = Form(...),
    encargado: str = Form(...),
    telefono: str = Form(...),
    grupo_id: str = Form(...),
    comprobante: UploadFile = File(...),
):
    grupo = next((g for g in GRUPOS if g["id"] == grupo_id), None)
    if not grupo:
        raise HTTPException(status_code=404, detail="Grupo no encontrado")

    if grupo["cupos_ocupados"] >= grupo["cupos_max"]:
        raise HTTPException(status_code=409, detail="Cupo lleno")

    ext = os.path.splitext(comprobante.filename)[1]
    nombre_archivo = f"{uuid.uuid4()}{ext}"
    ruta = os.path.join(UPLOAD_DIR, nombre_archivo)

    with open(ruta, "wb") as f:
        f.write(await comprobante.read())

    grupo["cupos_ocupados"] += 1

    matricula_id = str(uuid.uuid4())
    codigo = f"YE-{uuid.uuid4().hex[:6].upper()}"

    MATRICULAS[matricula_id] = {
        "id": matricula_id,
        "codigo": codigo,
        "estudiante": estudiante,
        "encargado": encargado,
        "telefono": telefono,
        "grupo_id": grupo_id,
        "estado": "pendiente",
        "comprobante": ruta,
    }

    return {
        "codigo": codigo,
        "estado": "pendiente",
    }

@app.get("/matricula/consultar/{codigo}")
def consultar_matricula(codigo: str):
    matricula = next(
        (m for m in MATRICULAS.values() if m["codigo"] == codigo),
        None,
    )

    if not matricula:
        raise HTTPException(status_code=404, detail="Código no encontrado")

    grupo = next(g for g in GRUPOS if g["id"] == matricula["grupo_id"])

    return {
        "codigo": matricula["codigo"],
        "estudiante": matricula["estudiante"],
        "encargado": matricula["encargado"],
        "telefono": matricula["telefono"],
        "curso": grupo["curso"],
        "horario": grupo["horario"],
        "estado": matricula["estado"],
    }

# =========================
# Admin
# =========================
@app.get("/admin/matriculas")
def ver_matriculas():
    return MATRICULAS

@app.post("/admin/aprobar/{matricula_id}")
def aprobar_matricula(matricula_id: str):
    matricula = MATRICULAS.get(matricula_id)
    if not matricula:
        raise HTTPException(status_code=404, detail="Matrícula no encontrada")

    matricula["estado"] = "aprobada"
    return {"ok": True}

@app.post("/admin/rechazar/{matricula_id}")
def rechazar_matricula(matricula_id: str):
    matricula = MATRICULAS.get(matricula_id)
    if not matricula:
        raise HTTPException(status_code=404, detail="Matrícula no encontrada")

    grupo = next(g for g in GRUPOS if g["id"] == matricula["grupo_id"])
    grupo["cupos_ocupados"] = max(0, grupo["cupos_ocupados"] - 1)

    matricula["estado"] = "rechazada"
    return {"ok": True}

@app.get("/admin/comprobante/{matricula_id}")
def ver_comprobante(matricula_id: str):
    matricula = MATRICULAS.get(matricula_id)
    if not matricula:
        raise HTTPException(status_code=404, detail="Matrícula no encontrada")

    ruta = matricula["comprobante"]
    if not os.path.exists(ruta):
        raise HTTPException(
            status_code=404,
            detail="Comprobante no encontrado",
        )

    return FileResponse(
        path=ruta,
        filename=os.path.basename(ruta),
        media_type="application/octet-stream",
    )
