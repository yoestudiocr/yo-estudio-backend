from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from uuid import uuid4
from sqlalchemy import select
import os

from database import SessionLocal, engine
from models import Base, Grupo, Matricula

app = FastAPI(title="Yo Estudio App")


from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://yo-estudio-cr.web.app",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "comprobantes"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Crear tablas
Base.metadata.create_all(bind=engine)

# ===== Seed inicial de grupos =====
def seed_grupos():
    db = SessionLocal()
    try:
        existe = db.execute(select(Grupo)).first()
        if existe:
            return  # ya hay grupos, no duplicar

        grupos = [
            Grupo(
                id="ucr_una_1_3",
                curso="Admisión UCR–UNA",
                inicio="2026-02-14",
                horario="1:00 p.m. – 3:00 p.m.",
                cupos_max=6,
                cupos_ocupados=0,
            ),
            Grupo(
                id="ucr_una_tec_10_12",
                curso="Admisión UCR–UNA–TEC",
                inicio="2026-02-14",
                horario="10:00 a.m. – 12:00 m.d.",
                cupos_max=6,
                cupos_ocupados=0,
            ),
            Grupo(
                id="ucr_una_tec_3_5",
                curso="Admisión UCR–UNA–TEC",
                inicio="2026-02-14",
                horario="3:00 p.m. – 5:00 p.m.",
                cupos_max=6,
                cupos_ocupados=0,
            ),
        ]

        db.add_all(grupos)
        db.commit()
        print("✅ Grupos iniciales creados")

    finally:
        db.close()


seed_grupos()

# Dependency DB
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ================= HOME =================

@app.get("/")
def home():
    return {"ok": True, "app": "Yo Estudio"}


# ================= GRUPOS =================

@app.get("/grupos")
def listar_grupos(db: Session = Depends(get_db)):
    grupos = db.query(Grupo).all()
    return [
        {
            "id": g.id,
            "curso": g.curso,
            "inicio": g.inicio,
            "horario": g.horario,
            "cupos_max": g.cupos_max,
            "cupos_ocupados": g.cupos_ocupados
        }
        for g in grupos
    ]


# ================= MATRÍCULA =================

@app.post("/matricula")
async def solicitar_matricula(
    estudiante: str = Form(...),
    encargado: str = Form(...),
    telefono: str = Form(...),
    grupo_id: str = Form(...),
    comprobante: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    grupo = db.query(Grupo).filter(Grupo.id == grupo_id).first()
    if not grupo:
        raise HTTPException(status_code=404, detail="Grupo no encontrado")

    if grupo.cupos_ocupados >= grupo.cupos_max:
        raise HTTPException(status_code=409, detail="Cupo lleno")

    ext = os.path.splitext(comprobante.filename)[1]
    filename = f"{uuid4()}{ext}"
    ruta = os.path.join(UPLOAD_DIR, filename)

    with open(ruta, "wb") as f:
        f.write(await comprobante.read())

    grupo.cupos_ocupados += 1

    matricula = Matricula(
        id=str(uuid4()),
        codigo=f"YE-{uuid4().hex[:6].upper()}",
        estudiante=estudiante,
        encargado=encargado,
        telefono=telefono,
        grupo_id=grupo_id,
        estado="pendiente",
        comprobante=ruta
    )

    db.add(matricula)
    db.commit()
    db.refresh(matricula)

    return {
        "codigo": matricula.codigo,
        "estado": matricula.estado
    }


# ================= CONSULTAR =================

@app.get("/matricula/consultar/{codigo}")
def consultar_matricula(codigo: str, db: Session = Depends(get_db)):
    m = db.query(Matricula).filter(Matricula.codigo == codigo).first()
    if not m:
        raise HTTPException(status_code=404, detail="Código no encontrado")

    grupo = db.query(Grupo).filter(Grupo.id == m.grupo_id).first()

    return {
        "codigo": m.codigo,
        "estudiante": m.estudiante,
        "encargado": m.encargado,
        "telefono": m.telefono,
        "curso": grupo.curso,
        "horario": grupo.horario,
        "estado": m.estado
    }


# ================= ADMIN =================

@app.get("/admin/matriculas")
def admin_matriculas(db: Session = Depends(get_db)):
    return {
        m.id: {
            "id": m.id,
            "codigo": m.codigo,
            "estudiante": m.estudiante,
            "encargado": m.encargado,
            "telefono": m.telefono,
            "grupo_id": m.grupo_id,
            "estado": m.estado
        }
        for m in db.query(Matricula).all()
    }


@app.post("/admin/aprobar/{matricula_id}")
def aprobar_matricula(matricula_id: str, db: Session = Depends(get_db)):
    m = db.query(Matricula).filter(Matricula.id == matricula_id).first()
    if not m:
        raise HTTPException(status_code=404, detail="No encontrada")

    m.estado = "aprobada"
    db.commit()
    return {"ok": True}


@app.post("/admin/rechazar/{matricula_id}")
def rechazar_matricula(matricula_id: str, db: Session = Depends(get_db)):
    m = db.query(Matricula).filter(Matricula.id == matricula_id).first()
    if not m:
        raise HTTPException(status_code=404, detail="No encontrada")

    grupo = db.query(Grupo).filter(Grupo.id == m.grupo_id).first()
    grupo.cupos_ocupados = max(0, grupo.cupos_ocupados - 1)

    m.estado = "rechazada"
    db.commit()
    return {"ok": True}


@app.get("/admin/comprobante/{matricula_id}")
def ver_comprobante(matricula_id: str, db: Session = Depends(get_db)):
    m = db.query(Matricula).filter(Matricula.id == matricula_id).first()
    if not m or not os.path.exists(m.comprobante):
        raise HTTPException(status_code=404, detail="No encontrado")

    return FileResponse(m.comprobante)
