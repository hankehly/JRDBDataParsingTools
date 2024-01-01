{{ config(materialized='table') }}

with
  bac as (
  select
    *
  from
    {{ ref('stg_jrdb__bac') }}
  ),

  kyi as (
  select
    *
  from
    {{ ref('stg_jrdb__kyi') }}
  ),

  sed as (
  select
    *
  from
    {{ ref('stg_jrdb__sed') }}
  ),

  tyb as (
  select
    *
  from
    {{ ref('stg_jrdb__tyb') }}
  ),

  kab as (
  select
    *
  from
    {{ ref('stg_jrdb__kab') }}
  ),

  horses as (
  select
    *
  from
    {{ ref('int_horses') }}
  ),

  win_odds as (
  select
    *
  from
    {{ ref('int_win_odds') }}
  ),

  place_odds as (
  select
    *
  from
    {{ ref('int_place_odds') }}
  ),

  win_payouts as (
  select
    *
  from
    {{ ref('int_win_payouts') }}
  ),

  place_payouts as (
  select
      *
  from
      {{ ref('int_place_payouts') }}
  ),

  base as (
  select
    sed."レースキー",
    sed."馬番",
    kyi."枠番",
    (SELECT "name" FROM {{ ref('場コード') }} WHERE "code" = sed."レースキー_場コード") as "場名",
    sed."競走成績キー_年月日" as "年月日",
    sed."レースキー_場コード" as "場コード",
    sed."騎手コード",
    sed."調教師コード",
    sed."レースキー_Ｒ",

    case
      when extract(month from sed."競走成績キー_年月日") <= 3 then 1
      when extract(month from sed."競走成績キー_年月日") <= 6 then 2
      when extract(month from sed."競走成績キー_年月日") <= 9 then 3
      when extract(month from sed."競走成績キー_年月日") <= 12 then 4
    end as "四半期",

    sed."競走成績キー_血統登録番号" as "血統登録番号",
    kyi."入厩年月日",
    -- For columns that could be NULL, prioritize SED, then TYB, then KYI
    -- to get as close to the real value as possible
    coalesce(sed."馬体重", tyb."馬体重") as "馬体重",
    coalesce(sed."馬体重増減", tyb."馬体重増減") as "馬体重増減",

    sed."レース条件_距離" as "距離",
    (SELECT "name" FROM {{ ref('馬場状態コード') }} WHERE "code" = sed."レース条件_馬場状態") as "馬場状態",
    sed."本賞金",
    sed."レース条件_頭数" as "頭数",
    sed."レース条件_トラック情報_芝ダ障害コード" as "トラック種別",
    sed."馬成績_着順" as "着順",
    lag(sed."馬成績_着順", 1) over (partition by sed."競走成績キー_血統登録番号" order by sed."競走成績キー_年月日") as "前走着順",
    lag(sed."馬成績_着順", 2) over (partition by sed."競走成績キー_血統登録番号" order by sed."競走成績キー_年月日") as "前々走着順",
    lag(sed."馬成績_着順", 3) over (partition by sed."競走成績キー_血統登録番号" order by sed."競走成績キー_年月日") as "前々々走着順",

    horses."生年月日",
    horses."瞬発戦好走馬_芝",
    horses."消耗戦好走馬_芝",
    horses."瞬発戦好走馬_ダート",
    horses."消耗戦好走馬_ダート",
    horses."瞬発戦好走馬_総合",
    horses."消耗戦好走馬_総合",
    horses."性別",

    -- Warning: SED and KAB differ significantly.
    -- You may need to remedy this to improve model performance.
    coalesce(
      sed."ＪＲＤＢデータ_馬場差",
      -- Eliminating BAC & KAB from here would allow you to remove them from the
      -- model entirely
      case
        when bac."レース条件_トラック情報_芝ダ障害コード" = 'ダート' then kab."ダ馬場差"
        else kab."芝馬場差"
      end,
      0
    ) as "馬場差",

    coalesce(sed."ＪＲＤＢデータ_ＩＤＭ", tyb."ＩＤＭ", kyi."ＩＤＭ") as "ＩＤＭ",

    (SELECT "name" FROM {{ ref('脚質コード') }} WHERE "code" = sed."レース脚質") as "脚質",

    coalesce(sed."馬成績_確定単勝オッズ", win_odds."単勝オッズ", tyb."単勝オッズ") as "単勝オッズ",
    coalesce(sed."確定複勝オッズ下", place_odds."複勝オッズ", tyb."複勝オッズ") as "複勝オッズ",

    -- tyb."騎手指数",
    -- tyb."情報指数",
    -- tyb."オッズ指数",
    -- tyb."パドック指数",
    -- tyb."脚元情報",

    kyi."激走指数",

    (SELECT "weather_condition" FROM {{ ref('天候コード') }} WHERE "code" = sed."天候コード") as "天候",

    coalesce(win_payouts."払戻金", 0) > 0 as "単勝的中",
    coalesce(win_payouts."払戻金", 0) as "単勝払戻金",
    coalesce(place_payouts."払戻金", 0) > 0 as "複勝的中",
    coalesce(place_payouts."払戻金", 0) as "複勝払戻金"
  from
    sed

  inner join
    bac
  on
    sed."レースキー" = bac."レースキー"

  inner join
    kyi
  on
    sed."レースキー" = kyi."レースキー"
    and sed."馬番" = kyi."馬番"

  inner join
    tyb
  on
    sed."レースキー" = tyb."レースキー"
    and sed."馬番" = tyb."馬番"

  inner join
    kab
  on
    kyi."開催キー" = kab."開催キー"
    and sed."競走成績キー_年月日" = kab."年月日"

  inner join
    horses
  on
    kyi."血統登録番号" = horses."血統登録番号"

  left join
    win_odds
  on
    sed."レースキー" = win_odds."レースキー"
    and sed."馬番" = win_odds."馬番"

  left join
    place_odds
  on
    sed."レースキー" = place_odds."レースキー"
    and sed."馬番" = place_odds."馬番"

  left join
    win_payouts
  on
    sed."レースキー" = win_payouts."レースキー"
    and sed."馬番" = win_payouts."馬番"

  left join
    place_payouts
  on
    sed."レースキー" = place_payouts."レースキー"
    and sed."馬番" = place_payouts."馬番"
  ),

  -- 参考:
  -- https://github.com/codeworks-data/mvp-horse-racing-prediction/blob/master/extract_features.py#L73
  -- https://medium.com/codeworksparis/horse-racing-prediction-a-machine-learning-approach-part-2-e9f5eb9a92e9
  horse_features as (
  select
    "レースキー",
    "馬番",

    -- whether the horse placed in the previous race
    case when lag("着順") over (partition by "血統登録番号" order by "年月日") <= 3 then true else false end as "前走トップ3", -- last_place

    -- previous race draw
    lag("枠番") over (partition by "血統登録番号" order by "年月日") as "前走枠番", -- last_draw

    "年月日" - "入厩年月日" as "入厩何日前", -- horse_rest_time
    "年月日" - "入厩年月日" < 15 as "入厩15日未満", -- horse_rest_lest14
    "年月日" - "入厩年月日" >= 35 as "入厩35日以上", -- horse_rest_over35
    "馬体重", -- declared_weight
    "馬体重増減" as "馬体重増減", -- diff_declared_weight
    "距離", -- distance
    coalesce("距離" - lag("距離") over (partition by "血統登録番号" order by "年月日"), 0) as "前走距離差", -- diff_distance
    extract(year from age("年月日", "生年月日")) + extract(month from age("年月日", "生年月日")) / 12 + extract(day from age("年月日", "生年月日")) / (12 * 30.44) AS "年齢", -- horse_age
    age("年月日", "生年月日") < '5 years' as "4歳以下",
    sum(case when age("年月日", "生年月日") < '5 years' then 1 else 0 end) over (partition by "レースキー") as "4歳以下頭数",
    coalesce(sum(case when age("年月日", "生年月日") < '5 years' then 1 else 0 end) over (partition by "レースキー") / cast("頭数" as numeric), 0) as "4歳以下割合",

    -- how many races this horse has run until now
    coalesce(cast(count(*) over (partition by "血統登録番号" order by "年月日") - 1 as integer), 0) as "レース数", -- horse_runs

    -- how many races this horse has won until now (incremented by one on the following race)
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号" order by "年月日") - cast("単勝的中" as integer) as integer), 0) as "1位完走", -- horse_wins

    -- how many races this horse has placed in until now (incremented by one on the following race)
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号" order by "年月日") - cast("複勝的中" as integer) as integer), 0) as "トップ3完走", -- horse_places

    -- ratio_win_horse
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号" order by "年月日") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "1位完走率",

    -- ratio_place_horse
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号" order by "年月日") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "トップ3完走率",

    -- horse_venue_runs
    coalesce(cast(count(*) over (partition by "血統登録番号", "場コード" order by "年月日") - 1 as integer), 0) as "場所レース数",

    -- horse_venue_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "場コード" order by "年月日") - cast("単勝的中" as integer) as integer), 0) as "場所1位完走",

    -- horse_venue_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "場コード" order by "年月日") - cast("複勝的中" as integer) as integer), 0) as "場所トップ3完走",

    -- ratio_win_horse_venue
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "場コード" order by "年月日") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "場コード" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "場所1位完走率",

    -- ratio_place_horse_venue
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "場コード" order by "年月日") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "場コード" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "場所トップ3完走率",

    -- horse_surface_runs
    coalesce(cast(count(*) over (partition by "血統登録番号", "トラック種別" order by "年月日") - 1 as integer), 0) as "トラック種別レース数",

    -- horse_surface_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "トラック種別" order by "年月日") - cast("単勝的中" as integer) as integer), 0) as "トラック種別1位完走",

    -- horse_surface_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "トラック種別" order by "年月日") - cast("複勝的中" as integer) as integer), 0) as "トラック種別トップ3完走",

    -- ratio_win_horse_surface
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "トラック種別" order by "年月日") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "トラック種別" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "トラック種別1位完走率",

    -- ratio_place_horse_surface
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "トラック種別" order by "年月日") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "トラック種別" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "トラック種別トップ3完走率",

    -- horse_going_runs
    coalesce(cast(count(*) over (partition by "血統登録番号", "馬場状態" order by "年月日") - 1 as integer), 0) as "馬場状態レース数",

    -- horse_going_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "馬場状態" order by "年月日") - cast("単勝的中" as integer) as integer), 0) as "馬場状態1位完走",

    -- horse_going_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "馬場状態" order by "年月日") - cast("複勝的中" as integer) as integer), 0) as "馬場状態トップ3完走",

    -- ratio_win_horse_going
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "馬場状態" order by "年月日") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "馬場状態" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "馬場状態1位完走率",

    -- ratio_place_horse_going
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "馬場状態" order by "年月日") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "馬場状態" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "馬場状態トップ3完走率",

    -- horse_distance_runs
    coalesce(cast(count(*) over (partition by "血統登録番号", "距離" order by "年月日") - 1 as integer), 0) as "距離レース数",

    -- horse_distance_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "距離" order by "年月日") - cast("単勝的中" as integer) as integer), 0) as "距離1位完走",

    -- horse_distance_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "距離" order by "年月日") - cast("複勝的中" as integer) as integer), 0) as "距離トップ3完走",

    -- ratio_win_horse_distance
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "距離" order by "年月日") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "距離" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "距離1位完走率",

    -- ratio_place_horse_distance
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "距離" order by "年月日") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "距離" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "距離トップ3完走率",

    -- horse_quarter_runs
    coalesce(cast(count(*) over (partition by "血統登録番号", "四半期" order by "年月日") - 1 as integer), 0) as "四半期レース数",

    -- horse_quarter_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "四半期" order by "年月日") - cast("単勝的中" as integer) as integer), 0) as "四半期1位完走",

    -- horse_quarter_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "四半期" order by "年月日") - cast("複勝的中" as integer) as integer), 0) as "四半期トップ3完走",

    -- ratio_win_horse_quarter
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "四半期" order by "年月日") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "四半期" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "四半期1位完走率",

    -- ratio_place_horse_quarter
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "四半期" order by "年月日") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "四半期" order by "年月日") - 1 as numeric)'
      )
    }}, 0) as "四半期トップ3完走率"

    from
      base
  ),

  owner_features as (
  select
    "レースキー",
    "馬番",

    -- jockey_runs
    coalesce(cast(count(*) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "騎手レース数",

    -- jockey_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "騎手1位完走",

    -- jockey_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "騎手トップ3完走",

    -- ratio_win_jockey
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "騎手1位完走率",

    -- ratio_place_jockey
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "騎手トップ3完走率",

    -- jockey_venue_runs
    coalesce(cast(count(*) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "騎手場所レース数",

    -- jockey_venue_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "騎手場所1位完走",

    -- jockey_venue_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "騎手場所トップ3完走",

    -- ratio_win_jockey_venue
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "騎手場所1位完走率",

    -- ratio_place_jockey_venue
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "騎手場所トップ3完走率",

    -- jockey_distance_runs
    coalesce(cast(count(*) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "騎手距離レース数",

    -- jockey_distance_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "騎手距離1位完走",

    -- jockey_distance_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "騎手距離トップ3完走",

    -- ratio_win_jockey_distance
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "騎手距離1位完走率",

    -- ratio_place_jockey_distance
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード", "距離" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "騎手距離トップ3完走率",

    -- trainer_runs
    coalesce(cast(count(*) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "調教師レース数",

    -- trainer_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "調教師1位完走",

    -- trainer_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "調教師トップ3完走",

    -- ratio_win_trainer
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "調教師1位完走率",

    -- ratio_place_trainer
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "調教師トップ3完走率",

    -- trainer_venue_runs
    coalesce(cast(count(*) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "調教師場所レース数",

    -- trainer_venue_wins
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "調教師場所1位完走",

    -- trainer_venue_places
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "調教師場所トップ3完走",

    -- ratio_win_trainer_venue
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "調教師場所1位完走率",

    -- ratio_place_trainer_venue
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "調教師場所トップ3完走率",

    -- Compute the standard rank of the horse on his last 3 races giving us an overview of his state of form
    cast(coalesce(power(前走着順 - 1, 2) + power(前々走着順 - 1, 2) + power(前々々走着順 - 1, 2), 0) as integer) as "過去3走順位平方和" -- horse_std_rank
  from
    base
  ),

  -- Todo:
  -- https://teddykoker.com/2019/12/beating-the-odds-machine-learning-for-horse-racing/
  teddykoker_blog_features as (
  select
    "レースキー",
    "馬番",

    -- Horse Win Percent: Horse’s win percent over the past 5 races.
    -- horse_win_percent_past_5_races
    {{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号" order by "年月日" rows between 5 preceding and 1 preceding) - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号" order by "年月日" rows between 5 preceding and 1 preceding) - 1 as numeric)'
      )
    }} as "過去5走勝率",

    -- horse_place_percent_past_5_races
    {{
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号" order by "年月日" rows between 5 preceding and 1 preceding) - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号" order by "年月日" rows between 5 preceding and 1 preceding) - 1 as numeric)'
      )
    }} as "過去5走トップ3完走率",

    -- Jockey Win Percent: Jockey’s win percent over the past 5 races.
    -- jockey_win_percent_past_5_races
    {{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ" rows between 5 preceding and 1 preceding) - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ" rows between 5 preceding and 1 preceding) - 1 as numeric)'
      )
    }} as "騎手過去5走勝率",

    -- jockey_place_percent_past_5_races
    {{
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ" rows between 5 preceding and 1 preceding) - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "騎手コード" order by "年月日", "レースキー_Ｒ" rows between 5 preceding and 1 preceding) - 1 as numeric)'
      )
    }} as "騎手過去5走トップ3完走率"
  from
    base
  ),

  prize_features as (
  select
    base."レースキー",
    base."馬番",

    -- prize_horse_cumulative
    coalesce(sum("本賞金") over (partition by "血統登録番号" order by "年月日") - "本賞金", 0) as "本賞金累計",

    -- avg_prize_wins_horse
    coalesce({{
      dbt_utils.safe_divide(
        'sum("本賞金") over (partition by "血統登録番号" order by "年月日") - "本賞金"',
        'horse_features."1位完走"'
      )
    }}, 0) as "1位完走平均賞金",

    -- avg_prize_runs_horse
    coalesce({{
      dbt_utils.safe_divide(
        'sum("本賞金") over (partition by "血統登録番号" order by "年月日") - "本賞金"',
        'horse_features."レース数"'
      )
    }}, 0) as "レース数平均賞金",

    -- prize_trainer_cumulative
    coalesce(sum("本賞金") over (partition by "調教師コード" order by "年月日") - "本賞金", 0) as "調教師本賞金累計",

    -- avg_prize_wins_trainer
    coalesce({{
      dbt_utils.safe_divide(
        'sum("本賞金") over (partition by "調教師コード" order by "年月日") - "本賞金"',
        'owner_features."調教師1位完走"'
      )
    }}, 0) as "調教師1位完走平均賞金",

    -- avg_prize_runs_trainer
    coalesce({{
      dbt_utils.safe_divide(
        'sum("本賞金") over (partition by "調教師コード" order by "年月日") - "本賞金"',
        'owner_features."調教師レース数"'
      )
    }}, 0) as "調教師レース数平均賞金",

    -- prize_jockey_cumulative
    coalesce(sum("本賞金") over (partition by "騎手コード" order by "年月日") - "本賞金", 0) as "騎手本賞金累計",

    -- avg_prize_wins_jockey
    coalesce({{
      dbt_utils.safe_divide(
        'sum("本賞金") over (partition by "騎手コード" order by "年月日") - "本賞金"',
        'owner_features."騎手1位完走"'
      )
    }}, 0) as "騎手1位完走平均賞金",

    -- avg_prize_runs_jockey
    coalesce({{
      dbt_utils.safe_divide(
        'sum("本賞金") over (partition by "騎手コード" order by "年月日") - "本賞金"',
        'owner_features."騎手レース数"'
      )
    }}, 0) as "騎手レース数平均賞金"
  from
    base
  inner join
    horse_features
  on
    base."レースキー" = horse_features."レースキー"
    and base."馬番" = horse_features."馬番"
  inner join
    owner_features
  on
    base."レースキー" = owner_features."レースキー"
    and base."馬番" = owner_features."馬番"
  ),

  combined_features as (
  select
    base."レースキー",
    base."馬番",

    -- horse/jockey/venue

    -- runs_horse_jockey
    coalesce(cast(count(*) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "馬騎手レース数",
    -- wins_horse_jockey
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "馬騎手1位完走",
    -- ratio_win_horse_jockey
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬騎手1位完走率",
    -- places_horse_jockey
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "馬騎手トップ3完走",
    -- ratio_place_horse_jockey
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬騎手トップ3完走率",
    -- first_second_jockey
    case when cast(count(*) over (partition by "血統登録番号", "騎手コード" order by "年月日", "レースキー_Ｒ") - 1 as integer) < 2 then true else false end as "馬騎手初二走",
    -- same_last_jockey (horse jockey combination was same last race)
    case when lag("騎手コード") over (partition by "血統登録番号" order by "年月日", "レースキー_Ｒ") = "騎手コード" then true else false end as "馬騎手同騎手",
    -- runs_horse_jockey_venue
    coalesce(cast(count(*) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "馬騎手場所レース数",
    -- wins_horse_jockey_venue
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "馬騎手場所1位完走",
    -- ratio_win_horse_jockey_venue
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬騎手場所1位完走率",
    -- places_horse_jockey_venue
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "馬騎手場所トップ3完走",
    -- ratio_place_horse_jockey_venue
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "騎手コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬騎手場所トップ3完走率",

    -- horse/trainer/venue

    -- runs_horse_trainer
    coalesce(cast(count(*) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "馬調教師レース数",
    -- wins_horse_trainer
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "馬調教師1位完走",
    -- ratio_win_horse_trainer
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬調教師1位完走率",
    -- places_horse_trainer
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "馬調教師トップ3完走",
    -- ratio_place_horse_trainer
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬調教師トップ3完走率",
    -- first_second_trainer
    case when cast(count(*) over (partition by "血統登録番号", "調教師コード" order by "年月日", "レースキー_Ｒ") - 1 as integer) < 2 then true else false end as "馬調教師初二走",
    -- same_last_trainer
    case when lag("調教師コード") over (partition by "血統登録番号" order by "年月日", "レースキー_Ｒ") = "調教師コード" then true else false end as "馬調教師同調教師",
    -- runs_horse_trainer_venue
    coalesce(cast(count(*) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as integer), 0) as "馬調教師場所レース数",
    -- wins_horse_trainer_venue
    coalesce(cast(sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer) as integer), 0) as "馬調教師場所1位完走",
    -- ratio_win_horse_trainer_venue
    coalesce({{
      dbt_utils.safe_divide(
        'sum(case when "着順" = 1 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("単勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬調教師場所1位完走率",
    -- places_horse_trainer_venue
    coalesce(cast(sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer) as integer), 0) as "馬調教師場所トップ3完走",
    -- ratio_place_horse_trainer_venue
    coalesce({{ 
      dbt_utils.safe_divide(
        'sum(case when "着順" <= 3 then 1 else 0 end) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - cast("複勝的中" as integer)',
        'cast(count(*) over (partition by "血統登録番号", "調教師コード", "場コード" order by "年月日", "レースキー_Ｒ") - 1 as numeric)'
      )
    }}, 0) as "馬調教師場所トップ3完走率"
  from
    base
  ),

  final as (
  select
    base."レースキー",
    base."馬番",
    "枠番",
    "場名",
    "年月日",
    "頭数",
    "四半期",
    "単勝的中",
    "単勝払戻金",
    "複勝的中",
    "複勝払戻金",
    "血統登録番号",
    "瞬発戦好走馬_芝",
    "消耗戦好走馬_芝",
    "瞬発戦好走馬_ダート",
    "消耗戦好走馬_ダート",
    "瞬発戦好走馬_総合",
    "消耗戦好走馬_総合",
    "性別",
    "馬場差",
    "馬場状態",
    "トラック種別",
    "ＩＤＭ",
    "脚質",
    "単勝オッズ",
    "複勝オッズ",
    "激走指数",
    "天候",

    horse_features."前走トップ3",
    horse_features."前走枠番",
    horse_features."入厩何日前", -- horse_rest_time
    horse_features."入厩15日未満", -- horse_rest_lest14
    horse_features."入厩35日以上", -- horse_rest_over35
    horse_features."馬体重", -- declared_weight
    horse_features."馬体重増減", -- diff_declared_weight
    horse_features."距離", -- distance
    horse_features."前走距離差", -- diff_distance
    horse_features."年齢", -- horse_age (years)
    horse_features."4歳以下",
    horse_features."4歳以下頭数",
    horse_features."4歳以下割合",
    horse_features."レース数", -- horse_runs
    horse_features."1位完走", -- horse_wins
    horse_features."トップ3完走", -- horse_places
    horse_features."1位完走率",
    horse_features."トップ3完走率",
    horse_features."場所レース数", -- horse_venue_runs
    horse_features."場所1位完走", -- horse_venue_wins
    horse_features."場所トップ3完走", -- horse_venue_places
    horse_features."場所1位完走率", -- ratio_win_horse_venue
    horse_features."場所トップ3完走率", -- ratio_place_horse_venue
    horse_features."トラック種別レース数", -- horse_surface_runs
    horse_features."トラック種別1位完走", -- horse_surface_wins
    horse_features."トラック種別トップ3完走", -- horse_surface_places
    horse_features."トラック種別1位完走率", -- ratio_win_horse_surface
    horse_features."トラック種別トップ3完走率", -- ratio_place_horse_surface
    horse_features."馬場状態レース数", -- horse_going_runs
    horse_features."馬場状態1位完走", -- horse_going_wins
    horse_features."馬場状態トップ3完走", -- horse_going_places
    horse_features."馬場状態1位完走率", -- ratio_win_horse_going
    horse_features."馬場状態トップ3完走率", -- ratio_place_horse_going
    horse_features."距離レース数", -- horse_distance_runs
    horse_features."距離1位完走", -- horse_distance_wins
    horse_features."距離トップ3完走", -- horse_distance_places
    horse_features."距離1位完走率", -- ratio_win_horse_distance
    horse_features."距離トップ3完走率", -- ratio_place_horse_distance
    horse_features."四半期レース数", -- horse_quarter_runs
    horse_features."四半期1位完走", -- horse_quarter_wins
    horse_features."四半期トップ3完走", -- horse_quarter_places
    horse_features."四半期1位完走率", -- ratio_win_horse_quarter
    horse_features."四半期トップ3完走率", -- ratio_place_horse_quarter

    owner_features."騎手レース数", -- jockey_runs
    owner_features."騎手1位完走", -- jockey_wins
    owner_features."騎手トップ3完走", -- jockey_places
    owner_features."騎手1位完走率", -- ratio_win_jockey
    owner_features."騎手トップ3完走率", -- ratio_place_jockey
    owner_features."騎手場所レース数", -- jockey_venue_runs
    owner_features."騎手場所1位完走", -- jockey_venue_wins
    owner_features."騎手場所トップ3完走", -- jockey_venue_places
    owner_features."騎手場所1位完走率", -- ratio_win_jockey_venue
    owner_features."騎手場所トップ3完走率", -- ratio_place_jockey_venue
    owner_features."騎手距離レース数", -- jockey_distance_runs
    owner_features."騎手距離1位完走", -- jockey_distance_wins
    owner_features."騎手距離トップ3完走", -- jockey_distance_places
    owner_features."騎手距離1位完走率", -- ratio_win_jockey_distance
    owner_features."騎手距離トップ3完走率", -- ratio_place_jockey_distance
    owner_features."調教師レース数", -- trainer_runs
    owner_features."調教師1位完走", -- trainer_wins
    owner_features."調教師トップ3完走", -- trainer_places
    owner_features."調教師1位完走率", -- ratio_win_trainer
    owner_features."調教師トップ3完走率", -- ratio_place_trainer
    owner_features."調教師場所レース数", -- trainer_venue_runs
    owner_features."調教師場所1位完走", -- trainer_venue_wins
    owner_features."調教師場所トップ3完走", -- trainer_venue_places
    owner_features."調教師場所1位完走率", -- ratio_win_trainer_venue
    owner_features."調教師場所トップ3完走率", -- ratio_place_trainer_venue
    owner_features."過去3走順位平方和", -- horse_std_rank

    prize_features."本賞金累計", -- prize_horse_cumulative
    prize_features."1位完走平均賞金", -- avg_prize_wins_horse
    prize_features."レース数平均賞金", -- avg_prize_runs_horse
    prize_features."調教師本賞金累計", -- prize_trainer_cumulative
    prize_features."調教師1位完走平均賞金", -- avg_prize_wins_trainer
    prize_features."調教師レース数平均賞金", -- avg_prize_runs_trainer
    prize_features."騎手本賞金累計", -- prize_jockey_cumulative
    prize_features."騎手1位完走平均賞金", -- avg_prize_wins_jockey
    prize_features."騎手レース数平均賞金", -- avg_prize_runs_jockey

    combined_features."馬騎手レース数", -- runs_horse_jockey
    combined_features."馬騎手1位完走", -- wins_horse_jockey
    combined_features."馬騎手1位完走率", -- ratio_win_horse_jockey
    combined_features."馬騎手トップ3完走", -- places_horse_jockey
    combined_features."馬騎手トップ3完走率", -- ratio_place_horse_jockey
    combined_features."馬騎手初二走", -- first_second_jockey
    combined_features."馬騎手同騎手", -- same_last_jockey
    combined_features."馬騎手場所レース数", -- runs_horse_jockey_venue
    combined_features."馬騎手場所1位完走", -- wins_horse_jockey_venue
    combined_features."馬騎手場所1位完走率", -- ratio_win_horse_jockey_venue
    combined_features."馬騎手場所トップ3完走", -- places_horse_jockey_venue
    combined_features."馬騎手場所トップ3完走率", -- ratio_place_horse_jockey_venue
    combined_features."馬調教師レース数", -- runs_horse_trainer
    combined_features."馬調教師1位完走", -- wins_horse_trainer
    combined_features."馬調教師1位完走率", -- ratio_win_horse_trainer
    combined_features."馬調教師トップ3完走", -- places_horse_trainer
    combined_features."馬調教師トップ3完走率", -- ratio_place_horse_trainer
    combined_features."馬調教師初二走", -- first_second_trainer
    combined_features."馬調教師同調教師", -- same_last_trainer
    combined_features."馬調教師場所レース数", -- runs_horse_trainer_venue
    combined_features."馬調教師場所1位完走", -- wins_horse_trainer_venue
    combined_features."馬調教師場所1位完走率", -- ratio_win_horse_trainer_venue
    combined_features."馬調教師場所トップ3完走", -- places_horse_trainer_venue
    combined_features."馬調教師場所トップ3完走率", -- ratio_place_horse_trainer_venue

    tkb_features."過去5走勝率", -- horse_win_percent_past_5_races
    tkb_features."過去5走トップ3完走率", -- horse_place_percent_past_5_races
    tkb_features."騎手過去5走勝率", -- jockey_win_percent_past_5_races
    tkb_features."騎手過去5走トップ3完走率" -- jockey_place_percent_past_5_races

  from
    base
  inner join
    horse_features
  on
    base."レースキー" = horse_features."レースキー"
    and base."馬番" = horse_features."馬番"
  inner join
    owner_features
  on
    base."レースキー" = owner_features."レースキー"
    and base."馬番" = owner_features."馬番"
  inner join
    prize_features
  on
    base."レースキー" = prize_features."レースキー"
    and base."馬番" = prize_features."馬番"
  inner join
    combined_features
  on
    base."レースキー" = combined_features."レースキー"
    and base."馬番" = combined_features."馬番"
  inner join
    teddykoker_blog_features tkb_features
  on
    base."レースキー" = tkb_features."レースキー"
    and base."馬番" = tkb_features."馬番"
  )

select
  *
from
  final
