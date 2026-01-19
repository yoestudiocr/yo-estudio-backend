from sqlalchemy import Column, String, Integer
from database import Base

class Grupo(Base):
    __tablename__ = "grupos"

    id = Column(String, primary_key=True, index=True)
    curso = Column(String)
    inicio = Column(String)
    horario = Column(String)
    cupos_max = Column(Integer)
    cupos_ocupados = Column(Integer, default=0)


class Matricula(Base):
    __tablename__ = "matriculas"

    id = Column(String, primary_key=True, index=True)
    codigo = Column(String, unique=True, index=True)
    estudiante = Column(String)
    encargado = Column(String)
    telefono = Column(String)
    grupo_id = Column(String)
    estado = Column(String)
    comprobante = Column(String)
