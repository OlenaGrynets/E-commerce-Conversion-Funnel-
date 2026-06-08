WITH sessions_info AS (         --- перший СТЕ - це СТЕ сесії,тобто 1 строка це одна сессія плюс параметри які властиві сесії, тобто: 
SELECT
  user_pseudo_id,               --- унікальний номер псевдо-користувача 
  (                             --- унікальний номер сесії 
  SELECT value.int_value
  FROM UNNEST(event_params)
  WHERE key = 'ga_session_id'
  ) AS session_id,

  CONCAT(                       --- поеднання унікального номеру псевдо-користувача та унікального номеру сесії   
    user_pseudo_id,'_',
    CAST((
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key='ga_session_id'
    ) AS STRING)
  ) AS user_session_id,

  PARSE_DATE('%Y%m%d', event_date) AS start_session_date,  -- дата старту сесії

  --- сторінка на яку попав користувач   
  COALESCE(
  NULLIF(
    REGEXP_EXTRACT(
      (SELECT value.string_value 
       FROM UNNEST(event_params) 
       WHERE key = 'page_location'),
      r'https?://[^/]+/?([^?#]*)'
    ),
    ''
  ),
  'home'
) AS landing_page,

  --- данні девайсу користувача   
  device.category AS device_category,
  device.language AS device_language,
  device.operating_system AS device_operating_system,
  
  --- гео-данні користувача
  geo.country AS country, 
  
  --- дані звідки прийшов користувач  
  traffic_source.source AS trafic_source,
  traffic_source.medium AS medium,
  traffic_source.name AS campaign

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`  
WHERE event_name='session_start' --- беремо тількі ті дані по сесіям яка відповідають початку сесії
),

events AS (                     --- другий СТЕ - це СТЕ event-ів,тобто 1 строка це один event плюс параметри які властиві event-ам, тобто: 
SELECT
  CONCAT(                       --- поеднання унікального номеру псевдо-користувача та унікального номеру сесії для звязку таблиць  
    user_pseudo_id,'_',
    CAST((
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key='ga_session_id'
    ) AS STRING)
  ) AS user_session_id,

  
  --- дані по event-ам
  event_name,
  DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_timestamp_date,
  
  ---комерційні дані по event-ам
  ecommerce.purchase_revenue_in_usd, 
    
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_name IN (    --- беремо тількі ті дані по event-ам потрібним для будування воронки
  'session_start',
  'view_item',
  'add_to_cart',
  'begin_checkout',
  'add_shipping_info',
  'add_payment_info',
  'purchase'
)
)
--- зєднуємо ці дві СТЕ через left-join 
SELECT
  s.user_pseudo_id,
  s.session_id,
  s.user_session_id,
  s.landing_page,
  s.device_category,
  s.device_language,
  s.device_operating_system,
  s.country,
  s.trafic_source,
  s.medium,
  s.campaign,

  e.event_name,
  s.start_session_date,
  e.event_timestamp_date,
  e.purchase_revenue_in_usd
    
FROM sessions_info s
LEFT JOIN events e
ON s.user_session_id = e.user_session_id
