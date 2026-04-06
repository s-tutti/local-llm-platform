import os
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.http_client = httpx.AsyncClient(base_url=OLLAMA_BASE_URL, timeout=300.0)
    yield
    await app.state.http_client.aclose()


app = FastAPI(
    title="LLM Platform API Gateway",
    version="0.1.0",
    lifespan=lifespan,
)


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.get("/readyz")
async def readyz(request: Request):
    try:
        resp = await request.app.state.http_client.get("/")
        resp.raise_for_status()
        return {"status": "ready", "ollama": "connected"}
    except httpx.HTTPError:
        raise HTTPException(status_code=503, detail="Ollama is not reachable")


@app.post("/api/generate")
async def generate(request: Request):
    body = await request.json()
    client: httpx.AsyncClient = request.app.state.http_client

    async def stream_response():
        async with client.stream("POST", "/api/generate", json=body) as resp:
            async for chunk in resp.aiter_bytes():
                yield chunk

    return StreamingResponse(stream_response(), media_type="application/x-ndjson")


@app.post("/api/chat")
async def chat(request: Request):
    body = await request.json()
    client: httpx.AsyncClient = request.app.state.http_client

    async def stream_response():
        async with client.stream("POST", "/api/chat", json=body) as resp:
            async for chunk in resp.aiter_bytes():
                yield chunk

    return StreamingResponse(stream_response(), media_type="application/x-ndjson")


@app.get("/api/tags")
async def list_models(request: Request):
    client: httpx.AsyncClient = request.app.state.http_client
    resp = await client.get("/api/tags")
    return resp.json()
