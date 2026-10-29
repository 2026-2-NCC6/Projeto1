-- Swing Sense - migration 002: estatisticas das tacadas e higiene dos dados.
--
-- SOMENTE ADITIVA: nao remove nem altera o significado de nenhuma coluna
-- existente, entao o backend e o app continuam funcionando sem mudanca.
-- Tudo roda numa unica transacao.
--
-- O que faz:
--  1. sessoes_treinamento.is_demo           marca as sessoes de demonstracao (seed)
--  2. sessoes_treinamento.avg/max_racket_speed_kmh
--                                           velocidade da RAQUETE (hoje o app grava
--                                           esse valor em *_ball_speed_kmh)
--  3. trigger em tacadas (INSERT)           mantem as colunas do item 2 e o
--                                           dispositivos.last_sync_at sempre em dia
--  4. tacadas.tipo aceita 'SQ' (saque)      o firmware ainda nao envia; o backend
--                                           ainda valida so FH/BH
--  5. dispositivos: unico por (user_id, device_identifier)
--  6. views de leitura (security_invoker)   estatisticas por sessao, por usuario e
--                                           qualidade das sessoes

-- 1) Sessoes de demonstracao ------------------------------------------------
ALTER TABLE public.sessoes_treinamento
  ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT false;

UPDATE public.sessoes_treinamento
   SET is_demo = true
 WHERE id IN (
   'b7ef6e71-131d-4431-97dc-2fe79eb5ab6c',  -- Rally de fundo
   '8cebedc8-af9e-4234-9c02-c7c37d3ffa21',  -- Treino de saque em ritmo
   'f72f8c7d-3f00-4c73-8a91-b237da4122d6'   -- Introducao ao manejo da raquete
 );

-- 2) Velocidade da raquete na sessao ---------------------------------------
ALTER TABLE public.sessoes_treinamento
  ADD COLUMN IF NOT EXISTS avg_racket_speed_kmh NUMERIC(5,1),
  ADD COLUMN IF NOT EXISTS max_racket_speed_kmh NUMERIC(5,1);

UPDATE public.sessoes_treinamento s
   SET avg_racket_speed_kmh = a.avg_vel,
       max_racket_speed_kmh = a.max_vel
  FROM (
    SELECT session_id, round(avg(vel)::numeric, 1) AS avg_vel, max(vel) AS max_vel
      FROM public.tacadas
     WHERE session_id IS NOT NULL
     GROUP BY session_id
  ) a
 WHERE s.id = a.session_id;

-- 3) Triggers em tacadas ----------------------------------------------------
CREATE OR REPLACE FUNCTION public.tacadas_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE sessoes_treinamento s
     SET avg_racket_speed_kmh = a.avg_vel,
         max_racket_speed_kmh = a.max_vel
    FROM (
      SELECT t.session_id, round(avg(t.vel)::numeric, 1) AS avg_vel, max(t.vel) AS max_vel
        FROM tacadas t
       WHERE t.session_id IN (SELECT DISTINCT session_id FROM novas WHERE session_id IS NOT NULL)
       GROUP BY t.session_id
    ) a
   WHERE s.id = a.session_id;

  UPDATE dispositivos d
     SET last_sync_at = now()
   WHERE EXISTS (
     SELECT 1 FROM novas n
      WHERE n.user_id = d.user_id AND n.dispositivo_id = d.device_identifier
   );

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS tacadas_after_insert ON public.tacadas;
CREATE TRIGGER tacadas_after_insert
  AFTER INSERT ON public.tacadas
  REFERENCING NEW TABLE AS novas
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.tacadas_after_insert();

-- Sincronismo do que ja existe (a trigger so cobre insercoes futuras).
UPDATE public.dispositivos d
   SET last_sync_at = x.ultima
  FROM (
    SELECT user_id, dispositivo_id, max(created_at) AS ultima
      FROM public.tacadas
     GROUP BY user_id, dispositivo_id
  ) x
 WHERE x.user_id = d.user_id AND x.dispositivo_id = d.device_identifier;

-- 4) Saque ------------------------------------------------------------------
ALTER TABLE public.tacadas DROP CONSTRAINT IF EXISTS tacadas_tipo_check;
ALTER TABLE public.tacadas
  ADD CONSTRAINT tacadas_tipo_check CHECK (tipo IN ('FH', 'BH', 'SQ'));

-- 5) Um dispositivo nao se repete para o mesmo usuario ------------------------
CREATE UNIQUE INDEX IF NOT EXISTS dispositivos_user_identifier_key
  ON public.dispositivos (user_id, device_identifier);

-- 6) Views de leitura -------------------------------------------------------
-- security_invoker: respeitam o RLS de quem consulta (sem isso, a view rodaria
-- com o dono e vazaria dados pela API publica do Supabase).
CREATE OR REPLACE VIEW public.v_tacadas_sessao
WITH (security_invoker = true) AS
SELECT
  t.session_id,
  t.user_id,
  count(*)                                         AS total,
  count(*) FILTER (WHERE t.tipo = 'FH')            AS forehand,
  count(*) FILTER (WHERE t.tipo = 'BH')            AS backhand,
  count(*) FILTER (WHERE t.tipo = 'SQ')            AS saque,
  count(*) FILTER (WHERE t.incerto)                AS incertas,
  round(100.0 * count(*) FILTER (WHERE t.incerto) / count(*), 1) AS pct_incertas,
  round(avg(t.acel)::numeric, 1)                   AS acel_media,
  round(max(t.acel)::numeric, 1)                   AS acel_max,
  round(avg(t.giro)::numeric, 1)                   AS giro_medio,
  round(max(t.giro)::numeric, 1)                   AS giro_max,
  round(avg(t.vel)::numeric, 1)                    AS vel_raquete_media,
  max(t.vel)                                       AS vel_raquete_max,
  min(t.recebido_em)                               AS primeira_tacada,
  max(t.recebido_em)                               AS ultima_tacada
FROM public.tacadas t
WHERE t.session_id IS NOT NULL
GROUP BY t.session_id, t.user_id;

CREATE OR REPLACE VIEW public.v_tacadas_usuario
WITH (security_invoker = true) AS
SELECT
  t.user_id,
  count(*)                              AS total,
  count(DISTINCT t.session_id)          AS sessoes,
  count(*) FILTER (WHERE t.tipo = 'FH') AS forehand,
  count(*) FILTER (WHERE t.tipo = 'BH') AS backhand,
  count(*) FILTER (WHERE t.tipo = 'SQ') AS saque,
  count(*) FILTER (WHERE t.incerto)     AS incertas,
  round(avg(t.vel)::numeric, 1)         AS vel_raquete_media,
  max(t.vel)                            AS vel_raquete_max,
  max(t.giro)                           AS giro_max,
  min(t.recebido_em)                    AS primeira_tacada,
  max(t.recebido_em)                    AS ultima_tacada
FROM public.tacadas t
GROUP BY t.user_id;

CREATE OR REPLACE VIEW public.v_sessoes_qualidade
WITH (security_invoker = true) AS
SELECT
  s.id,
  s.user_id,
  s.title,
  s.status,
  s.started_at,
  s.is_demo,
  s.device_id IS NOT NULL                                                  AS com_dispositivo,
  s.shot_count,
  (SELECT count(*) FROM public.eventos_sessao e WHERE e.session_id = s.id) AS eventos,
  (SELECT count(*) FROM public.tacadas t WHERE t.session_id = s.id)         AS tacadas,
  (s.shot_count = 0
     AND NOT EXISTS (SELECT 1 FROM public.eventos_sessao e WHERE e.session_id = s.id)
     AND NOT EXISTS (SELECT 1 FROM public.tacadas t WHERE t.session_id = s.id)) AS vazia
FROM public.sessoes_treinamento s;

-- As views nao devem ser legiveis pela chave publica (anon/authenticated).
REVOKE ALL ON public.v_tacadas_sessao, public.v_tacadas_usuario, public.v_sessoes_qualidade
  FROM anon, authenticated;
