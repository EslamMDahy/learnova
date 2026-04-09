from dotenv import load_dotenv
load_dotenv()  # ← لازم يكون أول حاجة قبل أي import تاني

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.features.auth.router                    import router as auth_router
from app.features.courses.router                 import router as courses_router
from app.features.learningOutcomes.router        import router as learningOutcomes_router
from app.features.modules.router                 import router as modules_router
from app.features.materials.router               import router as materials_router
from app.features.topics.router                  import router as topics_router
from app.features.questions.router               import router as questions_router
from app.features.organizations.router           import router as organizations_router
from app.features.settings.router                import router as settings_router

app = FastAPI()

origins = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(courses_router)
app.include_router(learningOutcomes_router)
app.include_router(modules_router)
app.include_router(materials_router)
app.include_router(topics_router)
app.include_router(questions_router)
app.include_router(organizations_router)
app.include_router(settings_router)