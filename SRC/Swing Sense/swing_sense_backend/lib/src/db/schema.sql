-- Swing Sense - schema do banco de dados (PostgreSQL / Supabase)
-- Referencia do modelo de dados ja criado no projeto Supabase usado pelo backend.
-- As tabelas usam nomes em portugues; as colunas usam os mesmos nomes em ingles
-- que `lib/src/mappers.dart` e `lib/src/db/postgres_store.dart` esperam.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.usuarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  level TEXT NOT NULL DEFAULT 'iniciante',
  birth_date DATE,
  city TEXT,
  role TEXT NOT NULL DEFAULT 'player',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  password_hash TEXT
);

CREATE TABLE IF NOT EXISTS public.seguimentos (
  follower_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id <> following_id)
);

-- Representa a raquete inteligente (ESP32 + giroscopio + sensor de velocidade da bola).
-- is_simulated = true ate o hardware real existir; o app usa um gerador de dados mockados
-- que respeita o mesmo contrato de telemetria desta tabela / rota /sessions/:id/events.
CREATE TABLE IF NOT EXISTS public.dispositivos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  device_name TEXT NOT NULL,
  device_identifier TEXT NOT NULL,
  firmware_version TEXT,
  is_simulated BOOLEAN NOT NULL DEFAULT true,
  paired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_sync_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.treinamentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  target_audience TEXT NOT NULL DEFAULT 'geral',
  difficulty TEXT NOT NULL DEFAULT 'iniciante',
  duration_minutes INT NOT NULL DEFAULT 30,
  focus TEXT,
  cover_color TEXT NOT NULL DEFAULT '1DB954',
  is_published BOOLEAN NOT NULL DEFAULT true,
  version INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sessoes_treinamento (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  training_id UUID REFERENCES public.treinamentos(id) ON DELETE SET NULL,
  device_id UUID REFERENCES public.dispositivos(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'in_progress',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  duration_seconds INT NOT NULL DEFAULT 0,
  shot_count INT NOT NULL DEFAULT 0,
  ace_count INT NOT NULL DEFAULT 0,
  avg_ball_speed_kmh NUMERIC(5,1),
  max_ball_speed_kmh NUMERIC(5,1),
  calories INT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.eventos_sessao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.sessoes_treinamento(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  ball_speed_kmh NUMERIC(5,1),
  spin_rate_rpm NUMERIC(6,1),
  racket_angle_deg NUMERIC(5,1),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.curtidas_sessao (
  session_id UUID NOT NULL REFERENCES public.sessoes_treinamento(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.comentarios_sessao (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.sessoes_treinamento(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.metas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  target_value NUMERIC(10,1) NOT NULL,
  current_value NUMERIC(10,1) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'un',
  deadline DATE,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.termos_glossario (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  term TEXT NOT NULL,
  category TEXT NOT NULL,
  short_explanation TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sessoes_user ON public.sessoes_treinamento(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_session ON public.eventos_sessao(session_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_seguimentos_following ON public.seguimentos(following_id);
