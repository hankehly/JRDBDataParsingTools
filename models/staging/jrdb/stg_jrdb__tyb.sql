with source as (
      select * from {{ source('jrdb', 'tyb') }}
),
final as (
    select
        concat(
            nullif("レースキー_場コード", ''),
            nullif("レースキー_年", ''),
            nullif("レースキー_回", ''),
            nullif("レースキー_日", ''),
            nullif("レースキー_Ｒ", '')
        ) as "レースキー",
        nullif("レースキー_場コード", '') as "レースキー_場コード",
        nullif("レースキー_年", '') as "レースキー_年",
        nullif("レースキー_回", '') as "レースキー_回",
        nullif("レースキー_日", '') as "レースキー_日",
        nullif("レースキー_Ｒ", '') as "レースキー_Ｒ",
        nullif("馬番", '') as "馬番",
        cast(nullif("ＩＤＭ", '') as numeric) as "ＩＤＭ",
        cast(nullif("騎手指数", '') as numeric) as "騎手指数",
        cast(nullif("情報指数", '') as numeric) as "情報指数",
        cast(nullif("オッズ指数", '') as numeric) as "オッズ指数",
        cast(nullif("パドック指数", '') as numeric) as "パドック指数",
        nullif("予備１", '') as "予備１",
        cast(nullif("総合指数", '') as numeric) as "総合指数",
        nullif("馬具変更情報", '') as "馬具変更情報",
        nullif("脚元情報", '') as "脚元情報",
        cast(nullif("取消フラグ", '') as boolean) as "取消フラグ",
        nullif("騎手コード", '') as "騎手コード",
        nullif("騎手名", '') as "騎手名",
        cast(nullif("負担重量", '') as integer) as "負担重量",
        nullif("見習い区分", '') as "見習い区分",
        nullif("馬場状態コード", '') as "馬場状態コード",
        nullif("天候コード", '') as "天候コード",

        cast(nullif("単勝オッズ", '') as numeric) as "単勝オッズ",
        cast(nullif("複勝オッズ", '') as numeric) as "複勝オッズ",
        cast(nullif(left("オッズ取得時間", 2) || ':' || right("オッズ取得時間", 2), '') as time) as "オッズ取得時間",
        cast(nullif("馬体重", '') as integer) as "馬体重",
        cast(nullif(replace(replace("馬体重増減", '+', ''), ' ', ''), '') as integer) as "馬体重増減",
        nullif("オッズ印", '') as "オッズ印",
        nullif("パドック印", '') as "パドック印",
        nullif("直前総合印", '') as "直前総合印",

        -- 0 is not a valid value for "馬体コード" but there are 42 rows with it.
        -- This is a workaround to avoid the error.
        case when "馬体コード" in (select code from {{ ref('馬体コード') }}) then "馬体コード" else null end "馬体コード",

        -- 0 is not a valid value for "気配コード" but there are 42 rows with it.
        -- This is a workaround to avoid the error.
        case when "気配コード" in (select code from {{ ref('気配コード') }}) then "気配コード" else null end "気配コード"

        -- values like "09:90" exist..
        -- case
        --   when "発走時間" = ''
        --     then null
        --   else
        --     cast(nullif(left("発走時間", 2) || ':' || right("発走時間", 2), '') as time)
        -- end "発走時間"
    from source
)
select * from final
  