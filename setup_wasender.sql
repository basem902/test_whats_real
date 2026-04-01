-- ============================================
-- WaSender Proxy via pgsql-http extension
-- Run this in Supabase SQL Editor
-- ============================================

-- Enable http extension (synchronous HTTP calls)
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- Drop old function
DROP FUNCTION IF EXISTS send_whatsapp(text, text);

-- Function using http extension (synchronous, reliable)
CREATE OR REPLACE FUNCTION send_whatsapp(
  p_phone text,
  p_message text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_response extensions.http_response;
  v_body text;
BEGIN
  v_body := json_build_object(
    'to', '+' || p_phone,
    'text', p_message
  )::text;

  SELECT * INTO v_response FROM extensions.http((
    'POST',
    'https://www.wasenderapi.com/api/send-message',
    ARRAY[
      extensions.http_header('Authorization', 'Bearer f56d0680ee5f69b96073c7714284a741d5b9c45d94bee3a5c4dd0cf8e54f9b7c'),
      extensions.http_header('Accept', 'application/json')
    ],
    'application/json',
    v_body
  )::extensions.http_request);

  IF v_response.status = 200 THEN
    RETURN json_build_object('success', true, 'status', v_response.status, 'body', v_response.content::json);
  ELSE
    RETURN json_build_object('success', false, 'status', v_response.status, 'body', v_response.content);
  END IF;

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION send_whatsapp(text, text) TO anon, authenticated, service_role;
