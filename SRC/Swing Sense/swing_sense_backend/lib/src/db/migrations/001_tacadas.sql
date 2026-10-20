-- Swing Sense - tabela de tacadas vindas da raquete real (BLE).
--
-- PROPOSTA para aplicar no Supabase (SQL Editor). Ainda NAO foi executada em
-- nenhum banco. Baseada em INTEGRACAO_APP_BLE.md, adaptada ao schema real:
-- `usuarios.id` e `sessoes_treinamento.id` sao UUID (o exemplo do guia usava
-- BIGINT), e os nomes seguem o padrao do projeto.
--
-- Identidade de uma tacada = (dispositivo_id, boot, seq). `seq` volta a 1 quando
-- o prototipo reinicia, mas `boot` muda junto, entao o trio nunca se repete.
-- A UNIQUE + `ON CONFLICT DO NOTHING` torna o envio idempotente (o app reenvia
-- sem duplicar; o futuro modo offline tambem depende disso).

CREATE TABLE IF NOT EXISTS public.tacadas (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  session_id      UUID REFERENCES public.sessoes_treinamento(id) ON DELETE SET NULL,
  dispositivo_id  TEXT NOT NULL,            -- nome anunciado, ex.: "SwingSense-A1B2" (nao usar remoteId)
  boot            BIGINT NOT NULL,          -- uint32 (ate 4294967295): INTEGER estoura
  seq             INTEGER NOT NULL,
  t_ms            BIGINT NOT NULL,          -- ms desde que o prototipo ligou (NAO e data/hora)
  recebido_em     TIMESTAMPTZ NOT NULL,     -- horario do celular ao receber
  tipo            CHAR(2) NOT NULL CHECK (tipo IN ('FH', 'BH')),
  incerto         BOOLEAN NOT NULL,
  bola            BOOLEAN,                  -- NULL = ainda nao medido
  acel            REAL NOT NULL,            -- pico de aceleracao (m/s2)
  giro            REAL NOT NULL,            -- pico de velocidade angular (rad/s)
  vel             INTEGER NOT NULL,         -- velocidade ESTIMADA da raquete (km/h), relativa
  accx            REAL NOT NULL,            -- valor interno da classificacao
  versao_formato  SMALLINT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (dispositivo_id, boot, seq)
);

CREATE INDEX IF NOT EXISTS tacadas_user_recebido_idx ON public.tacadas (user_id, recebido_em DESC);
CREATE INDEX IF NOT EXISTS tacadas_session_idx ON public.tacadas (session_id);

-- Todas as outras tabelas do projeto tem RLS ligado (conferido em 2026-10-19).
-- Sem RLS, a tabela ficaria exposta pela API publica do Supabase (chave anon).
-- A API Dart conecta direto pelo usuario do banco, igual as outras tabelas.
ALTER TABLE public.tacadas ENABLE ROW LEVEL SECURITY;
