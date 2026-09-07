-- Smart Sense - schema do banco de dados (PostgreSQL)
-- Aplicado automaticamente na primeira subida do container (docker-entrypoint-initdb.d)
-- ou manualmente pelo Database.migrate() ao iniciar o servidor.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  level TEXT NOT NULL DEFAULT 'iniciante',
  birth_date DATE,
  city TEXT,
  role TEXT NOT NULL DEFAULT 'player',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS follows (
  follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id <> following_id)
);

-- Representa a raquete inteligente (ESP32 + giroscopio + sensor de velocidade da bola).
-- is_simulated = true ate o hardware real existir; o app usa um gerador de dados mockados
-- que respeita o mesmo contrato de telemetria desta tabela / rota /sessions/:id/events.
CREATE TABLE IF NOT EXISTS devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name TEXT NOT NULL,
  device_identifier TEXT NOT NULL,
  firmware_version TEXT,
  is_simulated BOOLEAN NOT NULL DEFAULT true,
  paired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_sync_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS trainings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID REFERENCES users(id) ON DELETE SET NULL,
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

CREATE TABLE IF NOT EXISTS training_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  training_id UUID REFERENCES trainings(id) ON DELETE SET NULL,
  device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
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

CREATE TABLE IF NOT EXISTS session_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  ball_speed_kmh NUMERIC(5,1),
  spin_rate_rpm NUMERIC(6,1),
  racket_angle_deg NUMERIC(5,1),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS session_likes (
  session_id UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

CREATE TABLE IF NOT EXISTS session_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS goals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  target_value NUMERIC(10,1) NOT NULL,
  current_value NUMERIC(10,1) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'un',
  deadline DATE,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS glossary_terms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  term TEXT NOT NULL,
  category TEXT NOT NULL,
  short_explanation TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON training_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_session ON session_events(session_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);
