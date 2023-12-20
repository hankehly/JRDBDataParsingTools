# JRDBDataParsingTools

- [JRDBデータのご案内](http://www.jrdb.com/program/data.html)
- [ＪＲＤＢデータの種類と概要](http://www.jrdb.com/program/jrdb_data_doc.txt)
- [JRDBデータコード表](http://www.jrdb.com/program/jrdb_code.txt)
- [Data Index (restricted)](http://www.jrdb.com/member/dataindex.html)
- [馬券の種類：はじめての方へ](https://www.jra.go.jp/kouza/beginner/baken/)
- [PostgreSQL JDBC driver](https://jdbc.postgresql.org/download/)


![ER](./images/JRDB.drawio.png)

![schedule](./images/schedule.png)


### Table grain

| file |                                                                                                           | grain                                  | keys                                          | 更新時間                        | 実績/予測 |
| ---- | --------------------------------------------------------------------------------------------------------- | -------------------------------------- | --------------------------------------------- | ------------------------------- | --------- |
| SED  | 成績分析用                                                                                                | 1 race + horse                         | レースキー・馬番・競走成績キー（KYIとリンク） | 木 17:00                        | 成績情報  |
| SKB  | 成績分析用・拡張データ                                                                                    | 1 race + horse                         | レースキー・馬番・競走成績キー（KYIとリンク） | 木 17:00                        | 成績情報  |
| BAC  | レース番組情報                                                                                            | 1 race                                 | レースキー                                    | 金土	19:00                      | 前日情報  |
| CYB  | 調教分析データ                                                                                            | 1 race + horse                         | レースキー・馬番                              | 金土	19:00                      | 前日情報  |
| CHA  | 調教本追切データ                                                                                          | 1 race + horse                         | レースキー・馬番                              | 金土	19:00                      | 前日情報  |
| KAB  | 馬場・天候予想等の開催に対するデータ                                                                      | 1 place/day (e.g. tokyo on 2023/12/16) | 開催キー                                      | 金土	19:00                      | 前日情報  |
| KYI  | 競走馬ごとのデータ。IDM、各指数を格納、放牧先を追加                                                       | 1 race + horse                         | レースキー・馬番・血統登録番号                | 金土	19:00                      | 前日情報  |
| OZ   | 単複・馬連の基準オッズデータ                                                                              | 1 race                                 | レースキー                                    | 金土	19:00                      | 前日情報  |
| OW   | ワイドの基準オッズデータ                                                                                  | 1 race                                 | レースキー                                    | 金土	19:00                      | 前日情報  |
| OU   | 馬単の基準オッズデータ                                                                                    | 1 race                                 | レースキー                                    | 金土	19:00                      | 前日情報  |
| OT   | ３連複の基準オッズデータ                                                                                  | 1 race                                 | レースキー                                    | 金土	19:00                      | 前日情報  |
| OV   | ３連単の基準オッズデータ                                                                                  | 1 race                                 | レースキー                                    | 金土	19:00                      | 前日情報  |
| UKC  | 馬に関するデータを格納                                                                                    | 1 horse                                | 血統登録番号                                  | 金土	19:00                      | 前日情報  |
| TYB  | 直前情報データ                                                                                            | 1 race + horse                         | レースキー・馬番                              | 土日 発走15分前 & 17:00(最終版) | 当日情報  |
| HJC  | 払戻(実績)情報に関するデータを格納 (payout information, i.e. which horse won how much for what 馬券 type) | 1 race                                 | レースキー                                    | 土日 17:00                      | 当日情報  |


| キー         | 構成                                                                 |
| ------------ | -------------------------------------------------------------------- |
| レースキー   | 「場コード・年・回・日・Ｒ」の組み合わせ                             |
| 馬番         | 1-16など                                                             |
| 血統登録番号 | 99101712　など                                                       |
| 開催キー     | 「場コード・年・回・日」の組み合わせ。レースキーの一部とリンク可能。 |

