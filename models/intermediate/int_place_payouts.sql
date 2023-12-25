with
  final as (
  select
    レースキー,
    left(val, 2) as 馬番,
    cast(right(val, 7) as integer) as 払戻金
  FROM
    {{ ref('stg_jrdb__hjc') }},
    unnest(複勝払戻) as val
  where
    cast(left(val, 2) as integer) != 0
  )
select * from final