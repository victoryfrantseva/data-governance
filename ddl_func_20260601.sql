CREATE OR REPLACE FUNCTION dg_full.fill_meta_dq_business_table(p_out_schema text, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
/*
 * LGI 2026-05-25 last version
 * 
 * 
 */	
	
 
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    rec              record;
    v_cnt            int4;
    v_obj_group_id   bpchar(10);
    v_link_id        bpchar(10);
   	v_tmp_id        bpchar(10);
    v_res_obj_group  TEXT DEFAULT '';
    v_res_tmp        TEXT DEFAULT '';
    v_res_link       TEXT DEFAULT '';
    v_res_sch        TEXT DEFAULT '';
    v_res_obj  		TEXT DEFAULT '';
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );


   DROP TABLE IF EXISTS temp_max_file_id;
   DROP TABLE IF EXISTS temp_screen_templ;
   DROP TABLE IF EXISTS temp_schema;
   DROP TABLE IF EXISTS temp_del;
   DROP TABLE IF EXISTS temp_check_attr;
   DROP TABLE IF EXISTS temp_csv;
   DROP TABLE IF EXISTS temp_grp_list;
   DROP TABLE IF EXISTS temp_obj_list;
   DROP TABLE IF EXISTS temp_attr;

   

   
   ----------------------------------------------------------------

   CREATE TEMPORARY TABLE temp_csv AS
    SELECT p.schema_src_id,
           p.table_src_id,
           p.check_sql,
           p.screen_category
    FROM dg_full.meta_add_business_kkd p
    WHERE load_dttm::date=(SELECT max(load_dttm::date) from dg_full.meta_add_business_kkd)
   DISTRIBUTED BY (schema_src_id, table_src_id);
   RAISE NOTICE 'temp_csv';

-- полный список схем
CREATE TEMPORARY TABLE temp_schema AS
SELECT DISTINCT 
s.schema_src_id ,
1::int4 AS flg_has -- есть в списке схем
FROM s_grnplm_as_cib_gm_dg.meta_schema_ref_table s
UNION 
SELECT
v.schema_src_id ,
0::int4 AS flg_has -- нет в списке схем - добавить
FROM temp_csv v
DISTRIBUTED BY (schema_src_id);
RAISE NOTICE 'temp_schema';



CREATE TEMPORARY TABLE temp_attr AS 
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id,
    CASE WHEN pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char"]) THEN 'ctl'
         WHEN pgc.relkind = ANY (ARRAY['v'::"char", 'm'::"char"]) THEN 'view'
         ELSE '1'
    END AS period_run     
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN temp_schema s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_attr';



-- формирование скриптов
CREATE TEMPORARY TABLE temp_grp_list AS
WITH
temp_tbl AS (
SELECT DISTINCT 
    a.schema_src_id,
    a.table_src_id,
    a.object_id,
    a.period_run
FROM temp_attr a
)
, temp_add AS (
SELECT 
 t.screen_category AS screen_category_attr,
 t.check_sql
, t.schema_src_id 
, t.table_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' or  t.schema_src_id LIKE '%digital%' OR t.schema_src_id LIKE '%out_os_brief%'  THEN 'dm'
  END  AS etl_stage
FROM temp_csv t)
, temp_obj_ecxist AS (
SELECT ob.schema_src_id,
       ob.table_src_id,
       max(object_group_id) AS objgrp
       FROM temp_csv cs 
       LEFT JOIN dg_full.meta_object_ref_table ob ON cs.schema_src_id=cs.schema_src_id AND cs.table_src_id=ob.table_src_id AND object_alias='{{table_name}}'
       GROUP BY 1,2
)
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, NULL AS attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, tb.object_id::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_attr 
, 1::int8 AS object_order
, NULL::text AS attribute_type
, tb.period_run,
'{{table_name}}' AS object_alias,
exs.objgrp,
 dg_full.return_meta_query_to_check (REPLACE(tt.check_sql::TEXT,'''','''''')::TEXT, FALSE::boolean, FALSE::boolean) AS screen_sql
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
LEFT JOIN temp_obj_ecxist exs ON  tb.schema_src_id = exs.schema_src_id 
                AND tb.table_src_id = exs.table_src_id
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_grp_list';

-- meta_object_group_ref_table
  v_res_obj_group := '';
  v_res_tmp := '';
  v_res_link := '';
  v_res_obj := '';
  FOR rec IN (SELECT DISTINCT 
                     o.schema_src_id,
                     o.table_src_id,
                     o.attribute_src_id,
                     o.object_id AS grp_object_id,
                     o.tbl_object_id,
                     o.object_alias,
                     o.attribute_type,
                     o.object_order ,
                     o.screen_category_attr,
                     o.screen_sql,
                     o.period_run,
                     o.etl_stage,
                     o.objgrp
              FROM temp_grp_list o
              ) 
  LOOP
        RAISE NOTICE '%.meta_object_group_ref_table', p_out_schema::TEXT;
    -- Проверяем наличие и Заполняем meta_object_group_ref_table
         
        EXECUTE 'SELECT count(*)  
        FROM '|| p_out_schema || '.meta_object_ref_table
        WHERE 1=1
            AND schema_src_id = ''' || rec.schema_src_id || ''''||
            ' AND table_src_id= ''' ||rec.table_src_id   || ''''|| 
            'AND object_alias=''{{table_name}}'''
        INTO v_cnt;
       RAISE NOTICE 'group  exist  %', v_cnt; 
      
        IF rec.objgrp IS null THEN
          v_obj_group_id := nextval('dg_full.synth_key_seq');
         
          v_res_obj_group := v_res_obj_group || 
          ('INSERT INTO '|| p_out_schema || '.meta_object_group_ref_table (object_group_id, object_group_name,object_group_descr,load_dttm,wf_load_id, src_cd, is_active, object_group_type)
            VALUES ( '    ||
               v_obj_group_id || ',''' ||
               rec.schema_src_id || '.' ||
               rec.table_src_id   ||
               CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END ||
               COALESCE(rec.attribute_src_id,'')  || ''',''Автоматическое добавление'', current_timestamp, ' ||
               p_wf_load_id || ', ''GP'', 1, 2); ')::TEXT  || chr(10);
      
        v_res_obj := v_res_obj || 
              ('INSERT INTO '|| p_out_schema || '.meta_object_ref_table (
                         object_id,schema_src_id,table_src_id,attribute_src_id,attribute_type,object_order,is_active,load_dttm,wf_load_id,src_cd,node_type_src_id,object_group_id,object_alias)
                    VALUES ( '    ||
                       rec.tbl_object_id || ',''' ||
                       rec.schema_src_id || ''',''' || 
                       rec.table_src_id   || ''',null,null,' ||
                       rec.object_order   || ', 1, current_timestamp, ' ||
                       p_wf_load_id || ', ''GP'',1, ' ||
                       v_obj_group_id || ',''' ||
                       rec.object_alias || ''');'
                  )::TEXT  || chr(10);
                      
           

                     RAISE NOTICE 'v_res_obj ' ;    
                      
                ELSE
                
                RAISE NOTICE 'group  exist  %', v_cnt;  
        --   v_res_obj_group := v_res_obj_group ||     
          -- ('-- !! Группа есть ' || p_out_schema || '.meta_object_group_ref_table:'''    || 
            --       rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  ||''';')::TEXT || chr(10);
         
        END IF;
              
         RAISE NOTICE '%.meta_screen_template_ref_table', p_out_schema::TEXT;

              
               EXECUTE 'SELECT count(*) 
                FROM '|| p_out_schema || '.meta_screen_template_ref_table
                WHERE 1=1
                    AND screen_category =''' || rec.screen_category_attr || 
                   ''''
                INTO v_cnt;
   		               	 RAISE NOTICE 'v_res_tmp  st';
               
               IF COALESCE(v_cnt,0) = 0 THEN        
               	v_tmp_id := nextval('dg_full.synth_key_seq');
               -- !! 2024-11-13 IF COALESCE(v_cnt,0) = 0 THEN
                  v_res_tmp := v_res_tmp || 
                  ('INSERT INTO '|| p_out_schema || '.meta_screen_template_ref_table (
                        screen_template_id,screen_sql,screen_type,screen_category,is_direct_sql,load_dttm,wf_load_id,src_cd,descr,priority_cd)
                    VALUES ( '    ||
                       v_tmp_id || ',''' ||
                       rec.screen_sql || ''', 1,'''	 || 
                       rec.screen_category_attr   || ''', 1, current_timestamp, ' ||
                       p_wf_load_id || ', ''GP'', ''' ||
                       rec.screen_category_attr || ''', ''Low'');'
                  )::TEXT  || chr(10);            
              RAISE NOTICE 'v_res_tmp fsh: %' , rec.screen_category_attr::text;
          
    
                    v_link_id := nextval('dg_full.synth_key_seq');
    
                    v_res_link := v_res_link ||     
                    ('INSERT INTO '|| p_out_schema || '.meta_screen_link (
                        screen_id, screen_template_id, object_group_id, processing_order, etl_stage, default_severity_score, is_active, eff_from_dt, eff_to_dt, load_dttm, wf_load_id, src_cd, period_run, exception_group_id)
                    VALUES ('          || 
                    v_link_id              || ',' ||
                    v_tmp_id  || ',' ||
                    COALESCE(v_obj_group_id::text,rec.objgrp::text)         || ', 1, '''||
                    rec.etl_stage          || ''', 1, 1, ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,' ||
                    p_wf_load_id       || ', ''GP'', ''' || 
                    rec.period_run || ''', 1); ')::TEXT || chr(10);
             
                   
                   
                   RAISE NOTICE 'meta_screen_link ';
                
                    
                    ELSE
                  RAISE NOTICE 'v_res_tmp  else';
           v_res_tmp := v_res_tmp ||     
           ('-- !! Шаблон есть ' || p_out_schema || '.meta_screen_template_ref_table:''')::TEXT || chr(10);
         
        END IF; 
    
         END LOOP;
       
        


    
    
    
   EXECUTE           
         COALESCE(v_res_obj_group,'~') || chr(10)  ||
        COALESCE(v_res_obj,'~') || chr(10) ||
         COALESCE(v_res_tmp,'~') || chr(10) ||
         COALESCE(v_res_link,'~');
    
    RETURN  COALESCE(v_res_obj_group,'~') || chr(10)  ||
         COALESCE(v_res_obj,'~') || chr(10) ||
         COALESCE(v_res_tmp,'~') || chr(10) ||
         COALESCE(v_res_link,'~');
    
    

   
   
   
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_dq_parse_csv'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END;









$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_dq_parse_json(p_json json, p_out_schema text, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
    
/* Change Log 
 * FVV Формат json
*  
*/   
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    rec             record;
    rec_d           record;
    rec_l           record;
    v_json          json;
    v_cnt            int4;
    v_obj_group_id  bpchar(10);
    v_link_id       bpchar(10);
    v_res_obj_group TEXT DEFAULT '';
    v_res_obj       TEXT DEFAULT '';
    v_res_link      TEXT DEFAULT '';
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );

--   v_json := replace(replace('[{''table_src_id'': ''b2b_deals_deal'', ''object_id'': 46654172, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''contractid'', ''contractnum'', ''currencycode'', ''dealid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''closereasoncode'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''dealid'']]}]}, {''table_src_id'': ''b2b_deals_deal_task_relation'', ''object_id'': 46654152, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''dealid'', ''taskid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''dealid'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''dealid'', ''taskid'']]}]}, {''table_src_id'': ''b2b_deals_deal_team'', ''object_id'': 46654162, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''dealid'', ''dealteamid'', ''empnumber'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''createdby'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''dealid'', ''dealteamid'']]}]}, {''table_src_id'': ''b2b_deals_migration_offerteam'', ''object_id'': 175322957, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''offerteamid'', ''productofferid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''ctl_action'']}]}, {''table_src_id'': ''b2b_deals_offer_deal'', ''object_id'': 46654182, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''conditionsid'', ''contractid'', ''productofferid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''accountnum'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''productofferid'']]}]}, {''table_src_id'': ''b2b_deals_offer_task_relation'', ''object_id'': 46654192, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''taskid'', ''productofferid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''taskid'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''taskid'', ''productofferid'']]}]}, {''table_src_id'': ''b2b_deals_offeraddparams'', ''object_id'': 133918879, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''additionalparametercode'', ''productofferid'', ''additionalparametervalue'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''additionalparametercode'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''productofferid'']]}]}, {''table_src_id'': ''b2b_deals_product_offer'', ''object_id'': 46654202, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''dealid'', ''productofferid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''businessidsource'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''productofferid'']]}]}, {''table_src_id'': ''b2b_deals_task'', ''object_id'': 46654222, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''taskid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''approvalrequired'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''taskid'']]}]}, {''table_src_id'': ''b2b_deals_task_team'', ''object_id'': 46654212, ''schema_src_id'': ''s_grnplm_as_cib_gm_ods_sbercrm'', ''etl_stage'': ''ods'', ''screen_category'': [{''name'': ''% null'', ''attribute_src_id'': [''taskid'', ''taskteamid'']}, {''name'': ''Количество загруженных строк'', ''attribute_src_id'': [''taskid'']}, {''name'': ''Количество дублей по ключевым атрибутам'', ''attribute_src_id'': [[''taskid'']]}]}]'::text,'''''','"null"'), '''', '"')::json; 
    v_json := replace(replace(p_json::text,'''''','"null"'), '''', '"')::json;

   DROP TABLE IF EXISTS temp_json;
   DROP TABLE IF EXISTS temp_grp_list;
   DROP TABLE IF EXISTS temp_obj_list;
   ----------------------------------------------------------------
   -- парсинг json 
   CREATE TEMPORARY TABLE temp_json AS
    SELECT *
    FROM json_populate_recordset(NULL::record, v_json::json)
    AS (
        table_src_id    TEXT,
        object_id       TEXT,
        schema_src_id   TEXT,
        etl_stage       TEXT,
        screen_category TEXT
       )
   DISTRIBUTED BY (table_src_id);
   RAISE NOTICE 'temp_json';

   -- формирование скриптов
CREATE TEMPORARY TABLE temp_grp_list AS
WITH spr AS (
-- маппинг проверок из json и ИД проверок для метаданных
SELECT 
'stg' AS etl_stage,10011 AS screen_template_id , '% interval' AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,11 AS screen_template_id , '% interval' AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10004 AS screen_template_id , '% zero'AS screen_category_name 
UNION 
SELECT
'ods' AS etl_stage,4 AS screen_template_id , '% zero'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10003 AS screen_template_id , '% negative'AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,3 AS screen_template_id , '% negative'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10002 AS screen_template_id , '% unique'AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,2 AS screen_template_id , '% unique'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10001 AS screen_template_id , '% null'AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,1 AS screen_template_id , '% null'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10014 AS screen_template_id , 'Нарушение монотонности'AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,13 AS screen_template_id , 'Нарушение монотонности'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10073 AS screen_template_id , 'Количество загруженных строк'AS screen_category_name    
UNION 
SELECT
'ods' AS etl_stage,73 AS screen_template_id , 'Количество загруженных строк'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10074 AS screen_template_id , 'Количество дублей по ключевым атрибутам'AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,87 AS screen_template_id , 'Количество дублей по ключевым атрибутам'AS screen_category_name
UNION 
SELECT
'dm' AS etl_stage,10074 AS screen_template_id , 'Количество дублей по ключевым атрибутам'AS screen_category_name
UNION 
SELECT
'stg' AS etl_stage,10079 AS screen_template_id , 'Последняя расчетная дата'AS screen_category_name
UNION 
SELECT
'ods' AS etl_stage,10079 AS screen_template_id , 'Последняя расчетная дата'AS screen_category_name
)
, temp_attr AS (
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
)
, temp_tbl AS (
SELECT DISTINCT 
    a.schema_src_id,
    a.table_src_id,
    a.object_id
FROM temp_attr a
)
, temp_add AS (
SELECT 
  t1.schema_src_id 
, t1.table_src_id 
, CASE WHEN t1.screen_category_name  = 'Количество загруженных строк'
  THEN NULL::text
  ELSE REPLACE(UNNEST(string_to_array(
       CASE WHEN t1.screen_category_attribute_src_id like '%[[%' 
            THEN REPLACE(REPLACE(replace(t1.screen_category_attribute_src_id,'", "', ','),'[',''),']','')
            ELSE REPLACE(REPLACE(t1.screen_category_attribute_src_id,'[',''),']','')
  END , '", "') ) ,'"','' ) 
  END AS attribute_src_id     
, t1.object_id 
, t1.etl_stage 
, t1.screen_category_name 
, mst.screen_template_id
FROM  (
SELECT t.*
, json_array_elements(t.screen_category::json)->>'name' AS screen_category_name
, json_array_elements(t.screen_category::json)->>'attribute_src_id' AS screen_category_attribute_src_id
FROM temp_json t
) t1
JOIN spr ON t1.etl_stage = spr.etl_stage AND t1.screen_category_name = spr.screen_category_name
JOIN dg_full.meta_screen_template_ref_table mst ON spr.screen_template_id = mst.screen_template_id 
)
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, tt.attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, tb.object_id::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_name 
, tt.screen_template_id
, 1::int8 AS object_order
, NULL::text AS attribute_type
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NULL -- не указан атрибут 
UNION 
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, COALESCE(tt.attribute_src_id , ta.attribute_src_id) AS attribute_src_id    
, coalesce(tt.object_id::int8, ta.object_id::int8) AS  tbl_object_id
, ta.attr_id::int8 AS  object_id
, tt.etl_stage 
, tt.screen_category_name 
, tt.screen_template_id
, COALESCE(ta.object_order,1) AS object_order
, ta.attribute_type
FROM temp_add tt
JOIN  temp_attr ta ON ta.schema_src_id = tt.schema_src_id 
                  AND ta.table_src_id = tt.table_src_id 
                  AND ta.attribute_src_id = tt.attribute_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NOT NULL -- указан атрибут 
AND POSITION (',' IN tt.attribute_src_id) = 0 
UNION 
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, tt.attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, (tb.object_id::int8 * 1000000000 + 201)::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_name 
, tt.screen_template_id
, 201::int8 AS object_order
, 'text'::TEXT AS attribute_type
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NOT NULL -- указан атрибут 
AND POSITION (',' IN tt.attribute_src_id) <> 0 
DISTRIBUTED BY (table_src_id);
RAISE NOTICE 'temp_grp_list';

--SELECT * FROM temp_grp_list;

-- привязка атрибутов таблицы к алиасам
CREATE TEMPORARY TABLE temp_obj_list AS 
WITH 
temp_attr AS (
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
)
SELECT 
t.schema_src_id,
t.table_src_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN NULL::TEXT
     WHEN ma.attribute_src_id IS NOT NULL THEN ma.attribute_src_id
     ELSE t.attribute_src_id 
END AS attribute_src_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN t.tbl_object_id
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0  AND a.attribute_src_id IS NOT NULL THEN a.attr_id
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN (t.tbl_object_id::int8 * 1000000000 + 201)::int8
     ELSE t.object_id 
END AS object_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN 1::int8
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0 AND a.attribute_src_id IS NOT NULL THEN a.object_order
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN 201::int8
     ELSE t.object_order 
END AS object_order,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN NULL::TEXT
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0 AND a.attribute_src_id IS NOT NULL THEN a.attribute_type
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN 'bigint'::text
     ELSE t.attribute_type
END AS attribute_type,
t.etl_stage ,
t.screen_category_name ,
t.screen_template_id ,
ma.object_alias ,
t.object_id::int8 AS grp_object_id -- группа объектов для объединения
FROM temp_grp_list t
JOIN dg_full.meta_screen_template_alias_ref_table ma ON t.screen_template_id = ma.screen_template_id 
LEFT JOIN temp_attr a ON t.schema_src_id = a.schema_src_id 
                     AND t.table_src_id = a.table_src_id
                     AND ma.attribute_src_id = a.attribute_src_id
DISTRIBUTED BY (table_src_id);
RAISE NOTICE 'temp_obj_list';


-- meta_object_group_ref_table
  v_res_obj_group := '';
  v_res_obj := '';
  v_res_link := '';
  FOR rec IN (SELECT DISTINCT 
                     o.schema_src_id,
                     o.table_src_id,
                     o.attribute_src_id,
                     o.object_id AS grp_object_id
              FROM temp_grp_list o) 
  LOOP
        RAISE NOTICE '%.meta_object_group_ref_table', p_out_schema::TEXT;

    -- Проверяем наличие и Заполняем meta_object_group_ref_table
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_object_group_ref_table
        WHERE 1=1
            AND object_group_name = ''' || rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'') || ''''
        INTO v_cnt;
  
        IF COALESCE(v_cnt,0) = 0 THEN
          
          v_obj_group_id := nextval(p_out_schema || '.synth_key_seq');
      
          v_res_obj_group := v_res_obj_group || 
          ('INSERT INTO '|| p_out_schema || '.meta_object_group_ref_table (object_group_id, object_group_name,object_group_descr,load_dttm,wf_load_id, src_cd, is_active, object_group_type)
            VALUES ( '    ||
               v_obj_group_id || ',''' ||
               rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  || ''',''Автоматическое добавление'', current_timestamp, ' ||
               p_wf_load_id || ', ''GP'', 1, 2); ')::TEXT  || chr(10);
           
            -- meta_object_ref_table
            FOR rec_d IN (SELECT DISTINCT 
                            l.object_id ,
                            l.schema_src_id , 
                            l.table_src_id  , 
                            COALESCE(l.attribute_src_id,'')  AS attribute_src_id,
                            COALESCE(l.attribute_type,'')   AS attribute_type, 
                            l.object_order ,
                            v_obj_group_id ,
                            l.object_alias ,
                            l.grp_object_id
                          FROM temp_obj_list l 
                          WHERE l.schema_src_id = rec.schema_src_id 
                            AND l.table_src_id  = rec.table_src_id
                            AND l.grp_object_id = rec.grp_object_id
                          ORDER BY l.grp_object_id )
            LOOP 
                -- Проверяем наличие и Заполняем meta_object_ref_table
                EXECUTE 'SELECT count(*) 
                FROM '|| p_out_schema || '.meta_object_ref_table
                WHERE 1=1
                    AND object_id = ' || rec_d.object_id || 
                  ' AND object_id = ' || rec_d.grp_object_id ||
                  ' AND object_alias = ''' || rec_d.object_alias || ''''
                INTO v_cnt;
  
               -- !! 2024-11-13 IF COALESCE(v_cnt,0) = 0 THEN
                  v_res_obj := v_res_obj || 
                  ('INSERT INTO '|| p_out_schema || '.meta_object_ref_table (
                         object_id,schema_src_id,table_src_id,attribute_src_id,attribute_type,object_order,is_active,load_dttm,wf_load_id,src_cd,node_type_src_id,object_group_id,object_alias)
                    VALUES ( '    ||
                       rec_d.object_id || ',''' ||
                       rec_d.schema_src_id || ''',''' || 
                       rec_d.table_src_id   || ''',''' || 
                       rec_d.attribute_src_id   || ''',''' ||
                       rec_d.attribute_type   || ''',' ||
                       rec_d.object_order   || ', 1, current_timestamp, ' ||
                       p_wf_load_id || ',''GP'', 1, ' ||
                       rec_d.v_obj_group_id || ',''' ||
                       rec_d.object_alias || ''');'
                  )::TEXT  || chr(10);
               -- !! 2024-11-13 ELSE
               -- !! 2024-11-13     v_res_obj := v_res_obj ||     
               -- !! 2024-11-13     ('-- !! Привязка есть ' || p_out_schema || '.meta_object_ref_table:'''    || 
               -- !! 2024-11-13             rec_d.schema_src_id || '.' || rec_d.table_src_id   || CASE WHEN rec_d.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec_d.attribute_src_id,'')  ||''';')::TEXT || chr(10);
               -- !! 2024-11-13 END IF;
              RAISE NOTICE 'v_res_obj - %', v_res_obj::TEXT;
       
            END LOOP;
           
            FOR rec_l IN (SELECT DISTINCT 
                           o1.screen_template_id ,
                           o1.etl_stage
                        FROM temp_grp_list o1
                        WHERE o1.schema_src_id = rec.schema_src_id
                          AND o1.table_src_id  = rec.table_src_id
                          AND o1.object_id     = rec.grp_object_id) 
            LOOP
                RAISE NOTICE '%.meta_screen_link', p_out_schema::TEXT;
                -- Проверяем наличие и Заполняем связку meta_screen_link
                EXECUTE 'SELECT count(*)
                    FROM '|| p_out_schema || '.meta_screen_link sch 
                    WHERE 1=1
                        AND sch.screen_template_id = ''' || rec_l.screen_template_id  || '''' || 
                      ' AND sch.object_group_id = ''' || v_obj_group_id || ''''
                  INTO v_cnt;
      
                IF COALESCE(v_cnt,0) = 0 THEN
            
                    RAISE NOTICE 'v_res_link - INSERT %, %', v_res_link::TEXT, COALESCE(v_cnt,0)::TEXT;
    
                    v_link_id := nextval(p_out_schema || '.synth_key_seq');
    
                    v_res_link := v_res_link ||     
                    ('INSERT INTO '|| p_out_schema || '.meta_screen_link (
                        screen_id, screen_template_id, object_group_id, processing_order, etl_stage, default_severity_score, is_active, eff_from_dt, eff_to_dt, load_dttm, wf_load_id, src_cd, period_run, exception_group_id)
                    VALUES ('          || 
                    v_link_id              || ',' ||
                    rec_l.screen_template_id || ',' ||
                    v_obj_group_id         || ', 1, ''' ||
                    rec_l.etl_stage          || ''', 1, 1, ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,' ||
                    p_wf_load_id       || ', ''GP'', ''ctl'', 1); ')::TEXT || chr(10);
                ELSE
                    RAISE NOTICE 'v_res_link - UPDATE %, %', v_res_link::TEXT, COALESCE(v_cnt,0)::TEXT;
                END IF;
            END LOOP;
        
        ELSE
           v_res_obj_group := v_res_obj_group ||     
           ('-- !! Группа есть ' || p_out_schema || '.meta_object_group_ref_table:'''    || 
                   rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  ||''';')::TEXT || chr(10);
         
        END IF;
        RAISE NOTICE 'v_res_obj_group - %', v_res_obj_group::TEXT;
    
  END LOOP;            

-- проверка что все метаданные корректны
   
----------------------------------------------------------------------------------------------------
  
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_dq_parse_json'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN COALESCE(v_res_obj_group,'~') || chr(10)  ||
    COALESCE(v_res_obj,'~') || chr(10) ||
    COALESCE(v_res_link,'~')
    ;

    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_dq_parse_json'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END;



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_dq_parse_spod(p_in_schema text, p_in_table text, p_out_schema text, p_out_regime text, p_start_dt date, p_end_dt date, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
	
	
    
    
    
    
/* Change Log 
*  2024-12-12 FVV Формат Таблица из АС СПОД
*  2025-01-29 FVV Период определения загруженных данных p_start_dt \ p_end_dt -- +
*  2025-01-29 FVV Режимы загрузки: DML  - на выходе скрипты загрузки \ INS - вставка внутри функции
*  2025-01-29 FVV В dml добавить скрипты удаления
*  2025-01-29 FVV P_in_table маска наименования '% %' приходит с параметрами -- +
*  2025-01-29 FVV key_gen из конкретной схемы -- +
*  2025-02-13 FVV проверка наличичя схемы - если нет, то добавить
*  2025-02-19 FVV групировка атрибутов в проверке "Количество дублей" 
*  2025-02-19 FVV переназначение period_run ctl \ view
*  2025-04-09 FVV переназначение node_type_src_id - для "like $" = 12, иначе 1
*/   
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    rec              record;
    rec_d            record;
    rec_l            record;
    rec_dd           record;
    rec_sch          record;
    v_cnt            int4;
    v_obj_group_id   bpchar(10);
    v_link_id        bpchar(10);
    v_delete         TEXT DEFAULT '';
    v_res_obj_group  TEXT DEFAULT '';
    v_res_obj        TEXT DEFAULT '';
    v_res_link       TEXT DEFAULT '';
    v_res_sch        TEXT DEFAULT '';
    v_out_regime     TEXT DEFAULT 'DML';
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );


   DROP TABLE IF EXISTS temp_max_file_id;
   DROP TABLE IF EXISTS temp_screen_templ;
   DROP TABLE IF EXISTS temp_schema;
   DROP TABLE IF EXISTS temp_del;
   DROP TABLE IF EXISTS temp_check_attr;
   DROP TABLE IF EXISTS temp_csv;
   DROP TABLE IF EXISTS temp_grp_list;
   DROP TABLE IF EXISTS temp_obj_list;
   DROP TABLE IF EXISTS temp_attr;

   v_out_regime := coalesce(p_out_regime,'DML');
   
   CREATE TEMPORARY TABLE temp_max_file_id AS 
   SELECT 
   max (p1.dl_file_id::int8) AS max_file_id, 
   p1.schema_src_id, 
   p1.table_src_id 
   FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p1 
   WHERE 1=1
    AND p1.dl_create_date::date BETWEEN COALESCE(p_start_dt::date, (now()::date - '7 days'::interval)::date) AND COALESCE(p_end_dt::date, now()::date)
   GROUP BY 2,3
   ;
   
   ----------------------------------------------------------------
   -- парсинг таблицы из АС СПОД 
   -- забираем последние изменения по каждой таблице
   -- как обеспечить параллельную работу и загрузку данных от нескольких аналитиков?
   CREATE TEMPORARY TABLE temp_csv AS
    SELECT p.schema_src_id,
           p.table_src_id,
           p.attribute_src_id,
           p.group_prc,        -- 0 отдельный атрибут или группа атрибутов, обрабатываемые как один (через ",")
           p.prc_interval,     -- Процент допустимого значения
           p.prc_negative,     -- Процентт атрибутов\показателей, значение в которых < 0
           p.prc_null,         -- Процент заполнения атрибута - наличие NULL значений 
           p.prc_unique,       -- Процент уникальных значений
           p.prc_zero,         -- Процент атрибутов\показателей, значение в которых = 0
           p.cnt_takes,        -- Количество дублей
           p.last_recalc_date, -- Проверка наличиия актуальных данных
           p.monotony_break,   -- Проверка нарушения моготонности
           p.cnt_rows,         -- Количество загруженных строк
           p.story_num
    FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p
    JOIN temp_max_file_id f ON p.dl_file_id::int8 = f.max_file_id AND p.schema_src_id = f.schema_src_id AND p.table_src_id = f.table_src_id 
    WHERE 1=1
    AND p.dl_create_date::date BETWEEN COALESCE(p_start_dt::date, (now()::date - '7 days'::interval)::date) AND COALESCE(p_end_dt::date, now()::date)
    AND (p.schema_src_id  = p_in_schema OR COALESCE(p_in_schema,'') ='')
    AND (p.table_src_id LIKE p_in_table OR COALESCE(p_in_table,'') ='')
   DISTRIBUTED BY (schema_src_id, table_src_id);
   RAISE NOTICE 'temp_csv';

-- полный список схем
CREATE TEMPORARY TABLE temp_schema AS
SELECT DISTINCT 
s.schema_src_id ,
1::int4 AS flg_has -- есть в списке схем
FROM dg_full.meta_schema_ref_table s
UNION 
SELECT
v.schema_src_id ,
0::int4 AS flg_has -- нет в списке схем - добавить
FROM temp_csv v
DISTRIBUTED BY (schema_src_id);
RAISE NOTICE 'temp_schema';

-- Проверки для добавления - маппинг проверок из csv и ИД проверок для метаданных
CREATE TEMPORARY TABLE temp_screen_templ AS
SELECT * FROM (VALUES 
('dm'  ,10011 , '% interval'                              , 'prc_interval'),
('stg' ,10011 , '% interval'                              , 'prc_interval'),
('ods' ,11    , '% interval'                              , 'prc_interval'),
('dm'  ,10003 , '% negative'                              , 'prc_negative'),
('stg' ,10003 , '% negative'                              , 'prc_negative'),
('ods' ,3     , '% negative'                              , 'prc_negative'),
('dm'  ,10001 , '% null'                                  , 'prc_null'),
('stg' ,10001 , '% null'                                  , 'prc_null'),
('ods' ,1     , '% null'                                  , 'prc_null'),
('dm'  ,10002 , '% unique'                                , 'prc_unique'),
('stg' ,10002 , '% unique'                                , 'prc_unique'),
('ods' ,2     , '% unique'                                , 'prc_unique'),
('dm'  ,10004 , '% zero'                                  , 'prc_zero'),
('stg' ,10004 , '% zero'                                  , 'prc_zero'),
('ods' ,4     , '% zero'                                  , 'prc_zero'),
('dm'  ,10074 , 'Количество дублей по ключевым атрибутам' , 'cnt_takes'),
('stg' ,10074 , 'Количество дублей по ключевым атрибутам' , 'cnt_takes'),
('ods' ,87    , 'Количество дублей по ключевым атрибутам' , 'cnt_takes'),
('dm'  ,10078 , 'Последняя расчетная дата'                , 'last_recalc_date'),
('stg' ,10078 , 'Последняя расчетная дата'                , 'last_recalc_date'),
('ods' ,10078 , 'Последняя расчетная дата'                , 'last_recalc_date'),
('dm'  ,10014 , 'Нарушение монотонности'                  , 'monotony_break'),
('stg' ,10014 , 'Нарушение монотонности'                  , 'monotony_break'),
('ods' ,13    , 'Нарушение монотонности'                  , 'monotony_break'),
('dm'  ,10073 , 'Количество загруженных строк'            , 'cnt_rows'),    
('stg' ,10073 , 'Количество загруженных строк'            , 'cnt_rows'),    
('ods' ,73    , 'Количество загруженных строк'            , 'cnt_rows')
) tt(etl_stage,screen_template_id , screen_category_name, screen_category_attr)
DISTRIBUTED REPLICATED;
RAISE NOTICE 'temp_screen_templ';
   
   
-- проверка, что все таблицы\атрибуты присутствуют в метаданных gp

-- очищаем ранее добавленные проверки по объектам
CREATE TEMPORARY TABLE temp_del AS
SELECT 
v.*
FROM dg_full.vmeta_all_screen_link v
JOIN temp_csv cs ON v.schema_src_id = cs.schema_src_id AND v.table_src_id = cs.table_src_id 
JOIN temp_screen_templ spr ON v.screen_template_id = spr.screen_template_id 
WHERE 1=1
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_del';

/*
 * Наличие групп проверяем в процессе отработки скриптов
v_delete := '';
FOR rec_dd IN ( 
SELECT DISTINCT
d.screen_id, screen_template_id , object_group_id 
FROM temp_del d)
LOOP 
  v_delete := v_delete || 'DELETE FROM ' || p_out_schema::TEXT || '.meta_screen_link WHERE screen_id = ' || rec_dd.screen_id::TEXT || 
              ' AND screen_template_id = ' ||  rec_dd.screen_template_id::TEXT ||
              ' AND object_group_id = '    ||  rec_dd.object_group_id::TEXT || ';' ;
END LOOP;
FOR rec_dd IN ( 
SELECT DISTINCT
    object_group_id 
FROM temp_del d)
LOOP 
  v_delete := v_delete || 'DELETE FROM ' || p_out_schema::TEXT || '.meta_object_ref_table WHERE object_group_id = ' ||  rec_dd.object_group_id::TEXT || ';' ;
  v_delete := v_delete || 'DELETE FROM ' || p_out_schema::TEXT || '.meta_object_group_ref_table WHERE object_group_id = ' ||  rec_dd.object_group_id::TEXT || ';' ;
END LOOP;
IF v_delete = '' THEN v_delete := '--   Нет объектов для удаления'; END IF ;
*/

CREATE TEMPORARY TABLE temp_attr AS 
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id,
    CASE WHEN pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char"]) THEN 'ctl'
         WHEN pgc.relkind = ANY (ARRAY['v'::"char", 'm'::"char"]) THEN 'view'
         ELSE '1'
    END AS period_run     
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN temp_schema s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_attr';



-- формирование скриптов
CREATE TEMPORARY TABLE temp_grp_list AS
WITH
temp_tbl AS (
SELECT DISTINCT 
    a.schema_src_id,
    a.table_src_id,
    a.object_id,
    a.period_run
FROM temp_attr a
)
, temp_add AS (
SELECT 
  t1.schema_src_id 
, t1.table_src_id 
, t1.attribute_src_id     
, t1.etl_stage 
, t1.screen_category_attr 
, t1.screen_category_need_grp
, mst.screen_template_id
FROM  (
SELECT 
 'prc_interval' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_interval,'x') = 'x' THEN 'x' ELSE t.prc_interval END AS screen_category_need_grp 
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_interval IS NOT NULL 
UNION 
SELECT 
 'prc_negative' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_negative,'x') = 'x' THEN 'x' ELSE t.prc_negative END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_negative IS NOT NULL 
UNION 
SELECT 
 'prc_null' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_null,'x') = 'x' THEN 'x' ELSE t.prc_null END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_null IS NOT NULL 
UNION 
SELECT 
 'prc_unique' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_unique,'x') = 'x' THEN 'x' ELSE t.prc_unique END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_unique IS NOT NULL 
UNION 
SELECT 
 'prc_zero' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_zero,'x') = 'x' THEN 'x' ELSE t.prc_zero END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_zero IS NOT NULL 
UNION 
SELECT 
 'cnt_takes' AS screen_category_attr
, CASE WHEN COALESCE(t.cnt_takes,'x') = 'x' THEN 'x' ELSE t.cnt_takes END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, string_agg(t.attribute_src_id,',') AS attribute_src_id
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE cnt_takes IS NOT NULL 
GROUP BY 
CASE WHEN COALESCE(t.cnt_takes,'x') = 'x' THEN 'x' ELSE t.cnt_takes END
, t.schema_src_id 
, t.table_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END
UNION 
SELECT 
 'last_recalc_date' AS screen_category_attr
, CASE WHEN COALESCE(t.last_recalc_date,'x') = 'x' THEN 'x' ELSE t.last_recalc_date END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE last_recalc_date IS NOT NULL 
UNION 
SELECT 
 'monotony_break' AS screen_category_attr
, CASE WHEN COALESCE(t.monotony_break,'x') = 'x' THEN 'x' ELSE t.monotony_break END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE monotony_break IS NOT NULL 
UNION 
SELECT 
 'cnt_rows' AS screen_category_attr
, CASE WHEN COALESCE(t.cnt_rows,'x') = 'x' THEN 'x' ELSE t.cnt_rows END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE cnt_rows IS NOT NULL 
) t1
JOIN temp_screen_templ spr ON t1.etl_stage = spr.etl_stage AND t1.screen_category_attr = spr.screen_category_attr
JOIN dg_full.meta_screen_template_ref_table mst ON spr.screen_template_id = mst.screen_template_id 
)
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, tt.attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, tb.object_id::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_attr 
, tt.screen_category_need_grp
, tt.screen_template_id
, 1::int8 AS object_order
, NULL::text AS attribute_type
, tb.period_run
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NULL -- не указан атрибут 
UNION 
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, COALESCE(tt.attribute_src_id , ta.attribute_src_id) AS attribute_src_id    
, ta.object_id::int8 AS  tbl_object_id
, ta.attr_id::int8 AS  object_id
, tt.etl_stage 
, tt.screen_category_attr 
, tt.screen_category_need_grp
, tt.screen_template_id
, COALESCE(ta.object_order,1) AS object_order
, ta.attribute_type
, ta.period_run
FROM temp_add tt
JOIN  temp_attr ta ON ta.schema_src_id = tt.schema_src_id 
                  AND ta.table_src_id = tt.table_src_id 
                  AND ta.attribute_src_id = tt.attribute_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NOT NULL -- указан атрибут 
AND POSITION (',' IN tt.attribute_src_id) = 0 
UNION 
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, tt.attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, (tb.object_id::int8 * 1000000000 + 201)::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_attr 
, tt.screen_category_need_grp
, tt.screen_template_id
, 201::int8 AS object_order
, 'text'::TEXT AS attribute_type
, tb.period_run
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NOT NULL -- указан атрибут 
AND POSITION (',' IN tt.attribute_src_id) <> 0 
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_grp_list';

--SELECT * FROM temp_grp_list;

-- привязка атрибутов таблицы к алиасам
CREATE TEMPORARY TABLE temp_obj_list AS 
WITH 
temp_attr AS (
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN temp_schema s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
)
SELECT DISTINCT 
t.schema_src_id,
t.table_src_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN NULL::TEXT
     WHEN ma.attribute_src_id IS NOT NULL THEN ma.attribute_src_id
     ELSE t.attribute_src_id 
END AS attribute_src_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN t.tbl_object_id
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0  AND a.attribute_src_id IS NOT NULL THEN a.attr_id
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN (t.tbl_object_id::int8 * 1000000000 + 201)::int8
     ELSE t.object_id 
END AS object_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN 1::int8
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0 AND a.attribute_src_id IS NOT NULL THEN a.object_order
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN 201::int8
     ELSE t.object_order 
END AS object_order,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN NULL::TEXT
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0 AND a.attribute_src_id IS NOT NULL THEN a.attribute_type
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN 'bigint'::text
     ELSE t.attribute_type
END AS attribute_type,
t.etl_stage ,
t.screen_category_attr ,
t.screen_category_need_grp ,
t.screen_template_id ,
ma.object_alias 
, ma.object_order  AS ma_object_order
, t.object_id::int8 AS grp_object_id -- группа объектов для объединения
, t.period_run
FROM temp_grp_list t
JOIN dg_full.meta_screen_template_alias_ref_table ma ON t.screen_template_id = ma.screen_template_id 
LEFT JOIN temp_attr a ON t.schema_src_id = a.schema_src_id 
                     AND t.table_src_id = a.table_src_id
                     AND ma.attribute_src_id = a.attribute_src_id
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_obj_list';

--SELECT * FROM temp_obj_list ;

v_res_sch := '';
FOR rec_sch IN (SELECT * FROM temp_schema s)
LOOP 
        RAISE NOTICE '%.meta_schema_ref_table', p_out_schema::TEXT;
        -- Проверяем наличие и Заполняем meta_schema_ref_table
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_schema_ref_table
        WHERE 1=1
            AND schema_src_id = ''' || rec_sch.schema_src_id || ''''
        INTO v_cnt;
    
        IF COALESCE(v_cnt,0) = 0 THEN
          v_res_sch := v_res_sch || 
          ('INSERT INTO '|| p_out_schema || '.meta_schema_ref_table (schema_src_id_id, schema_cd, descr,type, schema_type, load_dttm,wf_load_id, src_cd)
            VALUES ( '''    ||
               rec_sch.schema_src_id || ''',''' ||
               rec_sch.schema_src_id || ''',''' ||
               rec_sch.schema_src_id || ''',''ПРОМ'',''Schema'', current_timestamp, ' ||
               p_wf_load_id || ', ''GP''); ')::TEXT  || chr(10);
        ELSE
           v_res_sch := v_res_sch ||     
           ('-- !! Схема есть ' || p_out_schema || '.meta_schema_ref_table:'''    || 
                   rec_sch.schema_src_id || ''';')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_obj_group - %', v_res_obj_group::TEXT;
        
END LOOP;

-- meta_object_group_ref_table
  v_res_obj_group := '';
  v_res_obj := '';
  v_res_link := '';
  FOR rec IN (SELECT DISTINCT 
                     o.schema_src_id,
                     o.table_src_id,
                     o.attribute_src_id,
                     o.object_id AS grp_object_id
              FROM temp_grp_list o
              ) 
  LOOP
        RAISE NOTICE '%.meta_object_group_ref_table', p_out_schema::TEXT;

    -- Проверяем наличие и Заполняем meta_object_group_ref_table
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_object_group_ref_table
        WHERE 1=1
            AND object_group_name = ''' || rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'') || ''''
        INTO v_cnt;
  
        IF COALESCE(v_cnt,0) = 0 THEN
          
          v_obj_group_id := nextval('dg_full.synth_key_seq');
      
          v_res_obj_group := v_res_obj_group || 
          ('INSERT INTO '|| p_out_schema || '.meta_object_group_ref_table (object_group_id, object_group_name,object_group_descr,load_dttm,wf_load_id, src_cd, is_active, object_group_type)
            VALUES ( '    ||
               v_obj_group_id || ',''' ||
               rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  || ''',''Автоматическое добавление'', current_timestamp, ' ||
               p_wf_load_id || ', ''GP'', 1, 2); ')::TEXT  || chr(10);
           
            -- meta_object_ref_table
            FOR rec_d IN (SELECT DISTINCT 
                            l.object_id ,
                            l.schema_src_id , 
                            l.table_src_id  , 
                            COALESCE(l.attribute_src_id,'')  AS attribute_src_id,
                            COALESCE(l.attribute_type,'')   AS attribute_type, 
                            l.object_order ,
                            v_obj_group_id ,
                            l.object_alias ,
                            l.grp_object_id
                          FROM temp_obj_list l 
                          WHERE l.schema_src_id =  rec.schema_src_id 
                            AND l.table_src_id  =  rec.table_src_id
                            AND l.grp_object_id = rec.grp_object_id
                          ORDER BY l.grp_object_id 
                          )
            LOOP 
                -- Проверяем наличие и Заполняем meta_object_ref_table
                EXECUTE 'SELECT count(*) 
                FROM '|| p_out_schema || '.meta_object_ref_table
                WHERE 1=1
                    AND object_id = ' || rec_d.object_id || 
                  ' AND object_id = ' || rec_d.grp_object_id ||
                  ' AND object_alias = ''' || rec_d.object_alias || ''''
                INTO v_cnt;
  
               -- !! 2024-11-13 IF COALESCE(v_cnt,0) = 0 THEN
                  v_res_obj := v_res_obj || 
                  ('INSERT INTO '|| p_out_schema || '.meta_object_ref_table (
                         object_id,schema_src_id,table_src_id,attribute_src_id,attribute_type,object_order,is_active,load_dttm,wf_load_id,src_cd,node_type_src_id,object_group_id,object_alias)
                    VALUES ( '    ||
                       rec_d.object_id || ',''' ||
                       rec_d.schema_src_id || ''',''' || 
                       rec_d.table_src_id   || ''',''' || 
                       rec_d.attribute_src_id   || ''',''' ||
                       rec_d.attribute_type   || ''',' ||
                       rec_d.object_order   || ', 1, current_timestamp, ' ||
                       p_wf_load_id || ', ''GP'', ' ||
                       CASE WHEN rec_d.attribute_src_id LIKE '%$%' THEN 12 ELSE 1 END  || ', ' ||
                       rec_d.v_obj_group_id || ',''' ||
                       rec_d.object_alias || ''');'
                  )::TEXT  || chr(10);
               -- !! 2024-11-13 ELSE
               -- !! 2024-11-13     v_res_obj := v_res_obj ||     
               -- !! 2024-11-13     ('-- !! Привязка есть ' || p_out_schema || '.meta_object_ref_table:'''    || 
               -- !! 2024-11-13             rec_d.schema_src_id || '.' || rec_d.table_src_id   || CASE WHEN rec_d.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec_d.attribute_src_id,'')  ||''';')::TEXT || chr(10);
               -- !! 2024-11-13 END IF;
              RAISE NOTICE 'v_res_obj - %', v_res_obj::TEXT;
       
            END LOOP;
           
            FOR rec_l IN (SELECT DISTINCT 
                           o1.screen_template_id ,
                           o1.etl_stage ,
                           o1.period_run
                        FROM temp_grp_list o1
                        WHERE o1.schema_src_id = rec.schema_src_id
                          AND o1.table_src_id  = rec.table_src_id
                          AND o1.object_id     = rec.grp_object_id) 
            LOOP
                RAISE NOTICE '%.meta_screen_link', p_out_schema::TEXT;
                -- Проверяем наличие и Заполняем связку meta_screen_link
                EXECUTE 'SELECT count(*)
                    FROM '|| p_out_schema || '.meta_screen_link sch 
                    WHERE 1=1
                        AND sch.screen_template_id = ''' || rec_l.screen_template_id  || '''' || 
                      ' AND sch.object_group_id = ''' || v_obj_group_id || ''''
                  INTO v_cnt;
      
                IF COALESCE(v_cnt,0) = 0 THEN
            
                    RAISE NOTICE 'v_res_link - INSERT %, %', v_res_link::TEXT, COALESCE(v_cnt,0)::TEXT;
    
                    v_link_id := nextval('dg_full.synth_key_seq');
    
                    v_res_link := v_res_link ||     
                    ('INSERT INTO '|| p_out_schema || '.meta_screen_link (
                        screen_id, screen_template_id, object_group_id, processing_order, etl_stage, default_severity_score, is_active, eff_from_dt, eff_to_dt, load_dttm, wf_load_id, src_cd, period_run, exception_group_id)
                    VALUES ('          || 
                    v_link_id              || ',' ||
                    rec_l.screen_template_id || ',' ||
                    v_obj_group_id         || ', 1, ''' ||
                    rec_l.etl_stage          || ''', 1, 1, ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,' ||
                    p_wf_load_id       || ', ''GP'', ''' || 
                    rec_l.period_run || ''', 1); ')::TEXT || chr(10);
                ELSE
                    RAISE NOTICE 'v_res_link - UPDATE %, %', v_res_link::TEXT, COALESCE(v_cnt,0)::TEXT;
                END IF;
            END LOOP;
        
        ELSE
           v_res_obj_group := v_res_obj_group ||     
           ('-- !! Группа есть ' || p_out_schema || '.meta_object_group_ref_table:'''    || 
                   rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  ||''';')::TEXT || chr(10);
         
        END IF;
        RAISE NOTICE 'v_res_obj_group - %', v_res_obj_group::TEXT;
    
  END LOOP;            

-- проверка что все метаданные корректны
   
----------------------------------------------------------------------------------------------------
  
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_dq_parse_csv'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
        
  IF v_out_regime = 'DML' THEN
  RETURN 
    COALESCE(v_delete,'~') || chr(10)  ||
    COALESCE(v_res_obj_group,'~') || chr(10)  ||
    COALESCE(v_res_obj,'~') || chr(10) ||
    COALESCE(v_res_link,'~')
    ;
    ELSE --IF v_out_regime = 'INS' THEN 
        EXECUTE     
         COALESCE(v_delete,'~') || chr(10)  ||
         COALESCE(v_res_obj_group,'~') || chr(10)  ||
         COALESCE(v_res_obj,'~') || chr(10) ||
         COALESCE(v_res_link,'~')
         ;
         RETURN 'Execute insert - ok' ;
END IF ;

    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_dq_parse_csv'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END;














$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_dq_parse_spod(p_in_schema text, p_in_table text, p_out_schema text, p_start_dt date, p_end_dt date, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
    
/* Change Log 
*  2024-12-12 FVV Формат Таблица из АС СПОД
*  2025-01-29 FVV Период определения загруженных данных p_start_dt \ p_end_dt -- +
*  2025-01-29 FVV Режимы загрузки: prom \ prom_dml \ ld \ ld_dml
*  2025-01-29 FVV В dml добавить скрипты удаления
*  2025-01-29 FVV P_in_table маска наименования '% %' приходит с параметрами -- +
*  2025-01-29 FVV key_gen из конкретной схемы -- +
*/   
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    rec              record;
    rec_d            record;
    rec_l            record;
    v_cnt            int4;
    v_obj_group_id   bpchar(10);
    v_link_id        bpchar(10);
    v_res_obj_group  TEXT DEFAULT '';
    v_res_obj        TEXT DEFAULT '';
    v_res_link       TEXT DEFAULT '';
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );


   DROP TABLE IF EXISTS temp_max_file_id;
   DROP TABLE IF EXISTS temp_csv;
   DROP TABLE IF EXISTS temp_grp_list;
   DROP TABLE IF EXISTS temp_obj_list;
   
   CREATE TEMPORARY TABLE temp_max_file_id AS 
   SELECT 
   max (p1.dl_file_id::int8) AS max_file_id, 
   p1.schema_src_id, 
   p1.table_src_id 
   FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p1 
   WHERE 1=1
    AND p1.dl_create_date::date BETWEEN COALESCE(p_start_dt::date, (now()::date - '7 days'::interval)::date) AND COALESCE(p_end_dt::date, now()::date)
   GROUP BY 2,3
   ;
   
   ----------------------------------------------------------------
   -- парсинг таблицы из АС СПОД 
   -- забираем последние изменения по каждой таблице
   -- как обеспечить параллельную работу и загрузку данных от нескольких аналитиков?
   CREATE TEMPORARY TABLE temp_csv AS
    SELECT p.schema_src_id,
           p.table_src_id,
           p.attribute_src_id,
           p.group_prc,        -- 0 отдельный атрибут или группа атрибутов, обрабатываемые как один (через ",")
           p.prc_interval,     -- Процент допустимого значения
           p.prc_negative,     -- Процентт атрибутов\показателей, значение в которых < 0
           p.prc_null,         -- Процент заполнения атрибута - наличие NULL значений 
           p.prc_unique,       -- Процент уникальных значений
           p.prc_zero,         -- Процентт атрибутов\показателей, значение в которых = 0
           p.cnt_takes,        -- Количество дублей
           p.last_recalc_date, -- Проверка наличиия актуальных данных
           p.monotony_break,   -- Проверка нарушения моготонности
           p.cnt_rows,         -- Количество загруженных строк
           p.story_num
    FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p
    JOIN temp_max_file_id f ON p.dl_file_id::int8 = f.max_file_id AND p.schema_src_id = f.schema_src_id AND p.table_src_id = f.table_src_id 
    WHERE 1=1
    AND p.dl_create_date::date BETWEEN COALESCE(p_start_dt::date, (now()::date - '7 days'::interval)::date) AND COALESCE(p_end_dt::date, now()::date)
    AND (p.schema_src_id  = p_in_schema OR COALESCE(p_in_schema,'') ='')
    AND (p.table_src_id LIKE p_in_table OR COALESCE(p_in_table,'') ='')
   DISTRIBUTED BY (schema_src_id, table_src_id);
   RAISE NOTICE 'temp_csv';
   
   -- проверка, что все таблицы\атрибуты присутствуют в метаданных gp
   
   -- очищаем ранее добавленные проверки по объектам

   -- формирование скриптов
CREATE TEMPORARY TABLE temp_grp_list AS
WITH spr AS (
-- маппинг проверок из csv и ИД проверок для метаданных
SELECT * FROM (VALUES 
('dm'  ,10011 , '% interval'                              , 'prc_interval'),
('stg' ,10011 , '% interval'                              , 'prc_interval'),
('ods' ,11    , '% interval'                              , 'prc_interval'),
('dm'  ,10003 , '% negative'                              , 'prc_negative'),
('stg' ,10003 , '% negative'                              , 'prc_negative'),
('ods' ,3     , '% negative'                              , 'prc_negative'),
('dm'  ,10001 , '% null'                                  , 'prc_null'),
('stg' ,10001 , '% null'                                  , 'prc_null'),
('ods' ,1     , '% null'                                  , 'prc_null'),
('dm'  ,10002 , '% unique'                                , 'prc_unique'),
('stg' ,10002 , '% unique'                                , 'prc_unique'),
('ods' ,2     , '% unique'                                , 'prc_unique'),
('dm'  ,10004 , '% zero'                                  , 'prc_zero'),
('stg' ,10004 , '% zero'                                  , 'prc_zero'),
('ods' ,4     , '% zero'                                  , 'prc_zero'),
('dm'  ,10074 , 'Количество дублей по ключевым атрибутам' , 'cnt_takes'),
('stg' ,10074 , 'Количество дублей по ключевым атрибутам' , 'cnt_takes'),
('ods' ,87    , 'Количество дублей по ключевым атрибутам' , 'cnt_takes'),
('dm'  ,10078 , 'Последняя расчетная дата'                , 'last_recalc_date'),
('stg' ,10078 , 'Последняя расчетная дата'                , 'last_recalc_date'),
('ods' ,10078 , 'Последняя расчетная дата'                , 'last_recalc_date'),
('dm'  ,10014 , 'Нарушение монотонности'                  , 'monotony_break'),
('stg' ,10014 , 'Нарушение монотонности'                  , 'monotony_break'),
('ods' ,13    , 'Нарушение монотонности'                  , 'monotony_break'),
('dm'  ,10073 , 'Количество загруженных строк'            , 'cnt_rows'),    
('stg' ,10073 , 'Количество загруженных строк'            , 'cnt_rows'),    
('ods' ,73    , 'Количество загруженных строк'            , 'cnt_rows')
) tt(etl_stage,screen_template_id , screen_category_name, screen_category_attr)
)
, temp_attr AS (
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
)
, temp_tbl AS (
SELECT DISTINCT 
    a.schema_src_id,
    a.table_src_id,
    a.object_id
FROM temp_attr a
)
, temp_add AS (
SELECT 
  t1.schema_src_id 
, t1.table_src_id 
, t1.attribute_src_id     
, t1.etl_stage 
, t1.screen_category_attr 
, t1.screen_category_need_grp
, mst.screen_template_id
FROM  (
SELECT 
 'prc_interval' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_interval,'x') = 'x' THEN 'x' ELSE t.prc_interval END AS screen_category_need_grp 
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_interval IS NOT NULL 
UNION 
SELECT 
 'prc_negative' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_negative,'x') = 'x' THEN 'x' ELSE t.prc_negative END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_negative IS NOT NULL 
UNION 
SELECT 
 'prc_null' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_null,'x') = 'x' THEN 'x' ELSE t.prc_null END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_null IS NOT NULL 
UNION 
SELECT 
 'prc_unique' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_unique,'x') = 'x' THEN 'x' ELSE t.prc_unique END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_unique IS NOT NULL 
UNION 
SELECT 
 'prc_zero' AS screen_category_attr
, CASE WHEN COALESCE(t.prc_zero,'x') = 'x' THEN 'x' ELSE t.prc_zero END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE prc_zero IS NOT NULL 
UNION 
SELECT 
 'cnt_takes' AS screen_category_attr
, CASE WHEN COALESCE(t.cnt_takes,'x') = 'x' THEN 'x' ELSE t.cnt_takes END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE cnt_takes IS NOT NULL 
UNION 
SELECT 
 'last_recalc_date' AS screen_category_attr
, CASE WHEN COALESCE(t.last_recalc_date,'x') = 'x' THEN 'x' ELSE t.last_recalc_date END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE last_recalc_date IS NOT NULL 
UNION 
SELECT 
 'monotony_break' AS screen_category_attr
, CASE WHEN COALESCE(t.monotony_break,'x') = 'x' THEN 'x' ELSE t.monotony_break END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE monotony_break IS NOT NULL 
UNION 
SELECT 
 'cnt_rows' AS screen_category_attr
, CASE WHEN COALESCE(t.cnt_rows,'x') = 'x' THEN 'x' ELSE t.cnt_rows END AS screen_category_need_grp
, t.schema_src_id 
, t.table_src_id 
, t.attribute_src_id 
, CASE WHEN t.schema_src_id LIKE '%ods%' THEN 'ods' 
       WHEN t.schema_src_id LIKE '%stg%' THEN 'stg'
       WHEN t.schema_src_id LIKE '%mart%' THEN 'dm'
  END  AS etl_stage
FROM temp_csv t
WHERE cnt_rows IS NOT NULL 
) t1
JOIN spr ON t1.etl_stage = spr.etl_stage AND t1.screen_category_attr = spr.screen_category_attr
JOIN dg_full.meta_screen_template_ref_table mst ON spr.screen_template_id = mst.screen_template_id 
)
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, tt.attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, tb.object_id::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_attr 
, tt.screen_category_need_grp
, tt.screen_template_id
, 1::int8 AS object_order
, NULL::text AS attribute_type
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NULL -- не указан атрибут 
UNION 
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, COALESCE(tt.attribute_src_id , ta.attribute_src_id) AS attribute_src_id    
, ta.object_id::int8 AS  tbl_object_id
, ta.attr_id::int8 AS  object_id
, tt.etl_stage 
, tt.screen_category_attr 
, tt.screen_category_need_grp
, tt.screen_template_id
, COALESCE(ta.object_order,1) AS object_order
, ta.attribute_type
FROM temp_add tt
JOIN  temp_attr ta ON ta.schema_src_id = tt.schema_src_id 
                  AND ta.table_src_id = tt.table_src_id 
                  AND ta.attribute_src_id = tt.attribute_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NOT NULL -- указан атрибут 
AND POSITION (',' IN tt.attribute_src_id) = 0 
UNION 
SELECT 
  tt.schema_src_id 
, tt.table_src_id 
, tt.attribute_src_id     
, tb.object_id::int8 AS tbl_object_id
, (tb.object_id::int8 * 1000000000 + 201)::int8 AS object_id
, tt.etl_stage 
, tt.screen_category_attr 
, tt.screen_category_need_grp
, tt.screen_template_id
, 201::int8 AS object_order
, 'text'::TEXT AS attribute_type
FROM temp_add tt
JOIN temp_tbl tb ON tb.schema_src_id = tt.schema_src_id 
                AND tb.table_src_id = tt.table_src_id
WHERE 1=1
AND  tt.attribute_src_id IS NOT NULL -- указан атрибут 
AND POSITION (',' IN tt.attribute_src_id) <> 0 
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_grp_list';

--SELECT * FROM temp_grp_list;

-- привязка атрибутов таблицы к алиасам
CREATE TEMPORARY TABLE temp_obj_list AS 
WITH 
temp_attr AS (
 SELECT DISTINCT 
    pgn.nspname::text  AS schema_src_id,
    pgc.relname::text  AS table_src_id,
    a.attname          AS attribute_src_id,
    a.attrelid::bigint AS object_id,
    a.attnum AS object_order,
    format_type(a.atttypid, a.atttypmod) AS attribute_type,
    a.attrelid::bigint * 1000000000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
  WHERE 1 = 1 
  AND pgc.relname !~~ '%_prt_%'::text 
  AND a.attnum > 0 
  AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
  AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
)
SELECT DISTINCT 
t.schema_src_id,
t.table_src_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN NULL::TEXT
     WHEN ma.attribute_src_id IS NOT NULL THEN ma.attribute_src_id
     ELSE t.attribute_src_id 
END AS attribute_src_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN t.tbl_object_id
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0  AND a.attribute_src_id IS NOT NULL THEN a.attr_id
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN (t.tbl_object_id::int8 * 1000000000 + 201)::int8
     ELSE t.object_id 
END AS object_id,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN 1::int8
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0 AND a.attribute_src_id IS NOT NULL THEN a.object_order
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN 201::int8
     ELSE t.object_order 
END AS object_order,
CASE WHEN ma.object_alias LIKE '%table_name%' THEN NULL::TEXT
     WHEN POSITION ('wf_load_id' IN ma.attribute_src_id) <> 0 AND a.attribute_src_id IS NOT NULL THEN a.attribute_type
     WHEN POSITION ('$' IN ma.attribute_src_id) <> 0 THEN 'bigint'::text
     ELSE t.attribute_type
END AS attribute_type,
t.etl_stage ,
t.screen_category_attr ,
t.screen_category_need_grp ,
t.screen_template_id ,
ma.object_alias 
, ma.object_order  AS ma_object_order
, t.object_id::int8 AS grp_object_id -- группа объектов для объединения
/*, CASE WHEN t.screen_category_need_grp = 'x' THEN t.object_id::TEXT 
                     ELSE t.tbl_object_id::text || '_' || t.screen_category_need_grp
                     END AS grp_object_id*/
FROM temp_grp_list t
JOIN dg_full.meta_screen_template_alias_ref_table ma ON t.screen_template_id = ma.screen_template_id 
LEFT JOIN temp_attr a ON t.schema_src_id = a.schema_src_id 
                     AND t.table_src_id = a.table_src_id
                     AND ma.attribute_src_id = a.attribute_src_id
DISTRIBUTED BY (schema_src_id, table_src_id);
RAISE NOTICE 'temp_obj_list';

--SELECT * FROM temp_obj_list ;

-- meta_object_group_ref_table
  v_res_obj_group := '';
  v_res_obj := '';
  v_res_link := '';
  FOR rec IN (SELECT DISTINCT 
                     o.schema_src_id,
                     o.table_src_id,
                     o.attribute_src_id,
                     o.object_id AS grp_object_id
                     /*CASE WHEN o.screen_category_need_grp = 'x' THEN o.object_id::TEXT 
                     ELSE o.tbl_object_id::text || '_' || o.screen_category_need_grp
                     END AS grp_object_id*/
              FROM temp_grp_list o
              ) 
  LOOP
        RAISE NOTICE '%.meta_object_group_ref_table', p_out_schema::TEXT;

    -- Проверяем наличие и Заполняем meta_object_group_ref_table
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_object_group_ref_table
        WHERE 1=1
            AND object_group_name = ''' || rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'') || ''''
        INTO v_cnt;
  
        IF COALESCE(v_cnt,0) = 0 THEN
          
          v_obj_group_id := nextval('dg_full.synth_key_seq');
      
          v_res_obj_group := v_res_obj_group || 
          ('INSERT INTO '|| p_out_schema || '.meta_object_group_ref_table (object_group_id, object_group_name,object_group_descr,load_dttm,wf_load_id, src_cd, is_active, object_group_type)
            VALUES ( '    ||
               v_obj_group_id || ',''' ||
               rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  || ''',''Автоматическое добавление'', current_timestamp, ' ||
               p_wf_load_id || ', ''GP'', 1, 2); ')::TEXT  || chr(10);
           
            -- meta_object_ref_table
            FOR rec_d IN (SELECT DISTINCT 
                            l.object_id ,
                            l.schema_src_id , 
                            l.table_src_id  , 
                            COALESCE(l.attribute_src_id,'')  AS attribute_src_id,
                            COALESCE(l.attribute_type,'')   AS attribute_type, 
                            l.object_order ,
                            v_obj_group_id ,
                            l.object_alias ,
                            l.grp_object_id
                          FROM temp_obj_list l 
                          WHERE l.schema_src_id =  rec.schema_src_id 
                            AND l.table_src_id  =  rec.table_src_id
                            AND l.grp_object_id = rec.grp_object_id
                          ORDER BY l.grp_object_id 
                          )
            LOOP 
                -- Проверяем наличие и Заполняем meta_object_ref_table
                EXECUTE 'SELECT count(*) 
                FROM '|| p_out_schema || '.meta_object_ref_table
                WHERE 1=1
                    AND object_id = ' || rec_d.object_id || 
                  ' AND object_id = ' || rec_d.grp_object_id ||
                  ' AND object_alias = ''' || rec_d.object_alias || ''''
                INTO v_cnt;
  
               -- !! 2024-11-13 IF COALESCE(v_cnt,0) = 0 THEN
                  v_res_obj := v_res_obj || 
                  ('INSERT INTO '|| p_out_schema || '.meta_object_ref_table (
                         object_id,schema_src_id,table_src_id,attribute_src_id,attribute_type,object_order,is_active,load_dttm,wf_load_id,src_cd,node_type_src_id,object_group_id,object_alias)
                    VALUES ( '    ||
                       rec_d.object_id || ',''' ||
                       rec_d.schema_src_id || ''',''' || 
                       rec_d.table_src_id   || ''',''' || 
                       rec_d.attribute_src_id   || ''',''' ||
                       rec_d.attribute_type   || ''',' ||
                       rec_d.object_order   || ', 1, current_timestamp, ' ||
                       p_wf_load_id || ',''GP'', 1, ' ||
                       rec_d.v_obj_group_id || ',''' ||
                       rec_d.object_alias || ''');'
                  )::TEXT  || chr(10);
               -- !! 2024-11-13 ELSE
               -- !! 2024-11-13     v_res_obj := v_res_obj ||     
               -- !! 2024-11-13     ('-- !! Привязка есть ' || p_out_schema || '.meta_object_ref_table:'''    || 
               -- !! 2024-11-13             rec_d.schema_src_id || '.' || rec_d.table_src_id   || CASE WHEN rec_d.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec_d.attribute_src_id,'')  ||''';')::TEXT || chr(10);
               -- !! 2024-11-13 END IF;
              RAISE NOTICE 'v_res_obj - %', v_res_obj::TEXT;
       
            END LOOP;
           
            FOR rec_l IN (SELECT DISTINCT 
                           o1.screen_template_id ,
                           o1.etl_stage
                        FROM temp_grp_list o1
                        WHERE o1.schema_src_id = rec.schema_src_id
                          AND o1.table_src_id  = rec.table_src_id
                          AND o1.object_id     = rec.grp_object_id) 
            LOOP
                RAISE NOTICE '%.meta_screen_link', p_out_schema::TEXT;
                -- Проверяем наличие и Заполняем связку meta_screen_link
                EXECUTE 'SELECT count(*)
                    FROM '|| p_out_schema || '.meta_screen_link sch 
                    WHERE 1=1
                        AND sch.screen_template_id = ''' || rec_l.screen_template_id  || '''' || 
                      ' AND sch.object_group_id = ''' || v_obj_group_id || ''''
                  INTO v_cnt;
      
                IF COALESCE(v_cnt,0) = 0 THEN
            
                    RAISE NOTICE 'v_res_link - INSERT %, %', v_res_link::TEXT, COALESCE(v_cnt,0)::TEXT;
    
                    v_link_id := nextval('dg_full.synth_key_seq');
    
                    v_res_link := v_res_link ||     
                    ('INSERT INTO '|| p_out_schema || '.meta_screen_link (
                        screen_id, screen_template_id, object_group_id, processing_order, etl_stage, default_severity_score, is_active, eff_from_dt, eff_to_dt, load_dttm, wf_load_id, src_cd, period_run, exception_group_id)
                    VALUES ('          || 
                    v_link_id              || ',' ||
                    rec_l.screen_template_id || ',' ||
                    v_obj_group_id         || ', 1, ''' ||
                    rec_l.etl_stage          || ''', 1, 1, ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,' ||
                    p_wf_load_id       || ', ''GP'', ''ctl'', 1); ')::TEXT || chr(10);
                ELSE
                    RAISE NOTICE 'v_res_link - UPDATE %, %', v_res_link::TEXT, COALESCE(v_cnt,0)::TEXT;
                END IF;
            END LOOP;
        
        ELSE
           v_res_obj_group := v_res_obj_group ||     
           ('-- !! Группа есть ' || p_out_schema || '.meta_object_group_ref_table:'''    || 
                   rec.schema_src_id || '.' || rec.table_src_id   || CASE WHEN rec.attribute_src_id IS NULL THEN '' ELSE '.' END || COALESCE(rec.attribute_src_id,'')  ||''';')::TEXT || chr(10);
         
        END IF;
        RAISE NOTICE 'v_res_obj_group - %', v_res_obj_group::TEXT;
    
  END LOOP;            

-- проверка что все метаданные корректны
   
----------------------------------------------------------------------------------------------------
  
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_dq_parse_csv'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN COALESCE(v_res_obj_group,'~') || chr(10)  ||
    COALESCE(v_res_obj,'~') || chr(10) ||
    COALESCE(v_res_link,'~')
    ;

    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_dq_parse_csv'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END;










$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_edge_link(p_src_tbl_src_id text, p_src_sch_src_id text, p_tgt_tbl_src_id text, p_tgt_sch_src_id text, p_edge_type_src_id int4, p_src_cd text, p_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
/* 
 * p_edge_type_src_id:
 * 8 - Связь
 * p_src_cd:
 * QS   
*/   
      
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    v_cnt            int4;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_src_sch_src_id = %I , p_src_tbl_src_id = %I , p_tgt_sch_src_id = %I , p_tgt_tbl_src_id = %I'
        , p_src_sch_src_id
        , p_src_tbl_src_id
        , p_tgt_sch_src_id
        , p_tgt_tbl_src_id
    );
       
    SELECT count(*) INTO v_cnt
    FROM dg_full.meta_edge_link t
    WHERE 1=1
      AND t.src_node_src_id = p_src_tbl_src_id
      AND t.src_schema_src_id = p_src_sch_src_id
      AND t.target_node_src_id = p_tgt_tbl_src_id
      AND t.target_schema_src_id = p_tgt_sch_src_id
  ;

    IF v_cnt IS NULL THEN 
        INSERT INTO dg_full.meta_edge_link (
edge_id,
load_dttm,
src_cd,
wf_load_id,
eff_from_dttm,
eff_to_dttm,
last_seen_dttm,
src_node_src_id,
src_schema_src_id,
target_node_src_id,
target_schema_src_id,
edge_type_src_id,
property_id,
weight,
order_by,
is_active
        )
        VALUES (
-1::int4
,current_timestamp
,p_src_cd
,p_wf_load_id
,'1900-12-31'::date
,'2099-01-01'::date
,current_timestamp
,p_src_tbl_src_id   
,p_src_sch_src_id   
,p_tgt_tbl_src_id
,p_tgt_sch_src_id
,p_edge_type_src_id
,NULL::int4
,1::NUMERIC(15,2)
,1::int4
,TRUE
);
    END IF;

    RETURN v_cnt
    ;
    
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_edge_link'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_node_ref_table(p_tbl_src_id text, p_sch_src_id text, p_src_cd text, p_node_type_src_id int4, p_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
/* 
 * p_node_type_src_id:
 * 7  Dashboard QS
 * 6  QVD
 * 13 Application QS  
 * */   
      
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    v_cnt            int4;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_sch_src_id = %I , p_tbl_src_id = %I '
        , p_sch_src_id
        , p_tbl_src_id
    );
       
    SELECT count(*) INTO v_cnt
    FROM dg_full.meta_node_ref_table t
    WHERE 1=1
      AND t.node_src_id = p_tbl_src_id
      AND t.schema_src_id = p_sch_src_id;

    IF v_cnt IS NULL THEN 
        INSERT INTO dg_full.meta_node_ref_table (
                node_src_id
               ,schema_src_id
               ,load_dttm
               ,src_cd
               ,wf_load_id
               ,eff_from_dttm
               ,eff_to_dttm
               ,last_seen_dttm
               ,node_cd
               ,node_name
               ,node_type_src_id
               ,is_active
               ,created_dt
               ,modified_dt
               )
        VALUES (
                p_tbl_src_id
               ,p_sch_src_id
               ,current_timestamp
               ,p_src_cd
               ,p_wf_load_id
               ,'1900-12-31'::date
               ,'2099-01-01'::date
               ,current_timestamp
               ,p_tbl_src_id
               ,p_tbl_src_id
               ,p_node_type_src_id
               ,TRUE
               ,current_timestamp
               ,current_timestamp
           );
    END IF;

    RETURN v_cnt
    ;
    
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_node_ref_table'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;



































$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_object_group_ref_table(p_tbl_src_id text, p_sch_src_id text, p_atr_src_id text, p_object_group_name text, p_object_group_descr text, p_is_active int4, p_object_group_type int4, p_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
/* Change Log 
 *   
 * */   
      
DECLARE
    v_params            TEXT DEFAULT '';
    v_res_statements    TEXT DEFAULT '';
    v_object_group_id   int8;
    v_object_group_name TEXT;
    v_cnt               int4;
    v_cnt_sch           int4;
    v_cnt_tbl           int4;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_sch_src_id = %I , p_tbl_src_id = %I , p_atr_src_id = %I'
        , p_sch_src_id
        , p_tbl_src_id
        , p_atr_src_id
    );
    -- Наличие схемы в списке схем ПКАП-а
    SELECT count(*) INTO v_cnt_sch
    FROM dg_full.meta_schema_ref_table t
    WHERE 1=1
      AND t.schema_src_id = p_sch_src_id
      ;
    IF coalesce(v_cnt_sch,0) = 0 THEN
        RETURN -2;    
    END IF;
    -- Наличие таблицы в списке таблиц
    SELECT count(*) INTO v_cnt_tbl
    FROM pg_class pgc 
    JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
    JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
    WHERE 1 = 1 
      AND pgc.relname !~~ '%_prt_%'::text 
      AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
      AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
      AND pgn.nspname::text = p_sch_src_id
      AND pgc.relname::text = p_tbl_src_id
    ;
    IF COALESCE(v_cnt_tbl,0) = 0 THEN
        RETURN -3;    
    END IF;
    -- Определение наименования группы
    IF p_atr_src_id IS NULL THEN 
        v_object_group_name := p_sch_src_id || '.' || p_tbl_src_id;
    ELSE 
    v_object_group_name := p_sch_src_id || '.' || p_tbl_src_id || '.' || p_atr_src_id;
    END IF;
    IF p_object_group_name IS NOT NULL THEN 
        v_object_group_name := p_object_group_name; 
    END IF;   
    -- наличие группы с одинаковым наименованием    
    SELECT count(*) INTO v_cnt
    FROM dg_full.meta_object_group_ref_table t
    WHERE 1=1
      AND t.object_group_name = v_object_group_name;

    IF COALESCE(v_cnt,0) = 0 THEN
        v_object_group_id := nextval('dg_full.synth_key_seq');
    
        INSERT INTO dg_full.meta_object_group_ref_table (
        object_group_id,
        object_group_name,
        object_group_descr,
        load_dttm,
        wf_load_id,
        src_cd,
        is_active,
        object_group_type)
        VALUES (
        v_object_group_id,
        v_object_group_name,
        p_object_group_descr,
        current_timestamp,
        p_wf_load_id,
        'GP',
        p_is_active,
        p_object_group_type
           );
    END IF;
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_object_group_ref_table'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN v_object_group_id::int4
    ;
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_object_group_ref_table'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_object_ref_table(p_tbl_src_id text, p_sch_src_id text, p_atr_src_id text, p_object_order int4, p_is_active int4, p_node_type_src_id int4, p_object_group_id int8, p_object_alias text, p_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
/* Change Log 
 *   
 * */   
      
DECLARE
    v_params            TEXT DEFAULT '';
    v_res_statements    TEXT DEFAULT '';
    v_object_id         int8;         -- из системной таблицы
    v_attribute_type    varchar(100); -- из системной таблицы 
    v_object_order      int4;         -- из системной таблицы
    v_table_order       int4;
    v_cnt               int4;
    v_cnt_sch           int4;
    v_cnt_tbl           int4;
    v_cnt_atr           int4;

BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_sch_src_id = %I , p_tbl_src_id = %I , p_atr_src_id = %I'
        , p_sch_src_id
        , p_tbl_src_id
        , p_atr_src_id
    );
    -- Наличие схемы в списке схем ПКАП-а
    SELECT count(*) INTO v_cnt_sch
    FROM dg_full.meta_schema_ref_table t
    WHERE 1=1
      AND t.schema_src_id = p_sch_src_id
      ;
    IF COALESCE(v_cnt_sch,0) = 0 THEN
        RETURN -2;    
    END IF;
    -- Наличие таблицы в списке таблиц
    SELECT count(*) INTO v_cnt_tbl
    FROM pg_class pgc 
    JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
    JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
    WHERE 1 = 1 
      AND pgc.relname !~~ '%_prt_%'::text 
      AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
      AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
      AND pgn.nspname::text = p_sch_src_id
      AND pgc.relname::text = p_tbl_src_id
    ;
    IF COALESCE(v_cnt_tbl,0) = 0 THEN
        RETURN -3;    
    END IF;
    -- проверка прописанного алиаса    
    IF p_object_alias IS NULL THEN 
        RETURN -4;    
    END IF;

    -- Наличие атрибута таблицы в списке атрибутов
    IF p_atr_src_id IS NOT NULL AND (p_atr_src_id NOT LIKE '%$%' OR p_atr_src_id NOT LIKE '%''%') THEN
        SELECT
        pgc.oid::bigint * 1000000000 + col_attr.attnum AS object_id,        
        format_type(col_attr.atttypid, col_attr.atttypmod) AS attribute_type,
        col_attr.attnum::integer AS object_order
        INTO v_object_id, v_attribute_type, v_object_order 
     FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
     WHERE 1 = 1 
      AND pgc.relname !~~ '%_prt_%'::text 
      AND a.attnum > 0 
      AND NOT a.attisdropped 
      AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
      AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
      AND pgn.nspname::text = p_sch_src_id
      AND pgc.relname::text = p_tbl_src_id
      AND a.attname::TEXT = p_atr_src_id
      ;
    END IF;
    -- При наличиии условий - вместо атрибута пишем условие проверки
    IF p_atr_src_id IS NOT NULL AND (p_atr_src_id LIKE '%$%' OR p_atr_src_id LIKE '%''%') THEN
      SELECT 
      pgc.oid::bigint * 1000000000 + p_object_order AS object_id,
      NULL::text AS attribute_type,
      p_object_order AS object_order 
      INTO v_object_id, v_attribute_type, v_object_order
        FROM pg_class pgc
        JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
        JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
        WHERE 1 = 1 
          AND pgc.relname !~~ '%_prt_%'::text AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
          AND pgn.nspname::text = p_sch_src_id
          AND pgc.relname::text = p_tbl_src_id;
    END IF;
    -- Не указан атрибут
    IF p_atr_src_id IS NULL THEN 
      SELECT pgc.oid::bigint AS object_id INTO v_object_id
        FROM pg_class pgc
        JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
        JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
        WHERE 1 = 1 
          AND pgc.relname !~~ '%_prt_%'::text AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
          AND pgn.nspname::text = p_sch_src_id
          AND pgc.relname::text = p_tbl_src_id;
      END IF;
  
    -- Наличие атрибута в группе    
    SELECT count(*) INTO v_cnt
    FROM dg_full.meta_object_ref_table t
    WHERE 1=1
      AND t.schema_src_id = p_sch_src_id
      AND t.table_src_id = p_tbl_src_id
      AND t.attribute_src_id =  p_atr_src_id
      AND t.object_group_id = p_object_group_id
      AND t.object_alias = p_object_alias;

    IF COALESCE(v_cnt,0) = 0 THEN
        INSERT INTO dg_full.meta_object_ref_table (
        object_id,
        schema_src_id,
        table_src_id,
        attribute_src_id,
        attribute_type,
        object_order,
        is_active,
        load_dttm,
        wf_load_id,
        src_cd,
        node_type_src_id,
        object_group_id,
        object_alias
        )
        VALUES (
        v_object_id,
        p_sch_src_id,
        p_tbl_src_id,
        p_atr_src_id,
        v_attribute_type,
        v_object_order,
        p_is_active,
        current_timestamp,
        p_wf_load_id,
        'GP',
        p_node_type_src_id,
        p_object_group_id,
        p_object_alias
        );
    END IF;
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_object_ref_table'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN v_object_group_id::int4
    ;
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_object_ref_table'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_parse_json(p_json json, p_out_schema text, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
    
    
    
    
    
/* Change Log 
 * FVV Формат json
*  
*/   
      
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    v_scheduler_id   bpchar(10);
    v_edge_id        bpchar(10);
    v_cnt            int4;
    v_cron           boolean;
    rec              record;
    v_json           json;
    v_res_schema     TEXT DEFAULT '';
    v_res_node       TEXT DEFAULT '';
    v_res_sched      TEXT DEFAULT '';
    v_res_edge       TEXT DEFAULT '';
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );

    RAISE NOTICE 'input, %', p_json;

    v_json := replace(replace(p_json::text,'''''','"null"'), '''', '"')::json;
    --v_json := p_json;

    CREATE TEMPORARY TABLE temp_json AS
    SELECT *
    FROM json_populate_recordset(NULL::record, v_json::json)
    AS (
       wf_name        TEXT,
       category       TEXT,
       src_table      TEXT,
       tgt_table      TEXT, 
       src_schema     TEXT,
       tgt_schema     TEXT,
       entity         TEXT,
       wf_time_sched  TEXT,
       wf_event_sched TEXT,
       cron_schedule  TEXT
       )
   DISTRIBUTED BY (wf_name);
   RAISE NOTICE 'temp_json';
   
CREATE TEMPORARY TABLE temp_espd AS
WITH tt AS (
SELECT t.wf_name,
       t.category,
       CASE WHEN t.src_table IN ('null') THEN NULL ELSE t.src_table END AS src_table,
       CASE WHEN t.tgt_table IN ('null') THEN NULL ELSE t.tgt_table END AS tgt_table, 
       CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS src_schema,
       CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS tgt_schema,
       CASE WHEN t.entity IN ('null') THEN NULL ELSE t.entity END AS entity,
       CASE WHEN t.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE t.wf_time_sched END AS wf_time_sched,
       CASE WHEN t.wf_event_sched IN ('null','[]') THEN NULL ELSE t.wf_event_sched END AS wf_event_sched,
       t.cron_schedule
FROM temp_json t
WHERE 1=1
AND t.category LIKE '%espd%'
   )
   SELECT
       COALESCE(tt.wf_name,'~') AS wf_name,
       COALESCE(tt.category,'~') AS category,
       COALESCE(tt.src_table,'~') AS src_table,
       COALESCE(tt.tgt_table,'~') AS tgt_table, 
       COALESCE(tt.src_schema,'~') AS src_schema,
       COALESCE(tt.tgt_schema,'~') AS tgt_schema,
       COALESCE(tt.entity,'~') AS entity,
       COALESCE(tt.wf_time_sched,'~') AS wf_time_sched,
       COALESCE(tt.wf_event_sched,'~') AS wf_event_sched,
       COALESCE(tt.cron_schedule,'~') AS cron_schedule 
       FROM tt
   DISTRIBUTED BY (wf_name);
RAISE NOTICE 'temp_espd';

CREATE TEMPORARY TABLE temp_ctl AS
WITH tt AS (
SELECT t.wf_name,
       t.category,
       CASE WHEN t.src_table IN ('null') THEN NULL ELSE t.src_table END AS src_table,
       CASE WHEN t.tgt_table IN ('null') THEN NULL ELSE t.tgt_table END AS tgt_table, 
       CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS src_schema,
       CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS tgt_schema,
       CASE WHEN t.entity IN ('null') THEN NULL ELSE t.entity END AS entity,
       CASE WHEN t.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE t.wf_time_sched END AS wf_time_sched,
       CASE WHEN t.wf_event_sched IN ('null','[]') THEN NULL ELSE t.wf_event_sched END AS wf_event_sched,
       CASE WHEN t.wf_event_sched IN ('null','[]') THEN NULL ELSE '{''''wf_event_sched'''': ' || CASE WHEN t.wf_event_sched IN ('null','[]') THEN 'ctl' ELSE t.wf_event_sched END || '}' END AS wf_event_sched_str,
       t.cron_schedule
FROM temp_json t
WHERE 1=1
AND t.category NOT LIKE '%espd%'
    )
    SELECT
       COALESCE(tt.wf_name, '~') AS wf_name,
       COALESCE(tt.category, '~') AS category,
       CASE WHEN POSITION ('.' IN COALESCE(tt.src_table, '~')) > 0 THEN substring(COALESCE(tt.src_table, '~') , POSITION ('.' IN COALESCE(tt.src_table, '~')) + 1 )  ELSE COALESCE(tt.src_table, '~') END AS src_table,   -- от "." до конца строки
       CASE WHEN POSITION ('.' IN COALESCE(tt.tgt_table, '~')) > 0 THEN substring(COALESCE(tt.tgt_table, '~') , POSITION ('.' IN COALESCE(tt.tgt_table, '~')) + 1 )  ELSE COALESCE(tt.tgt_table, '~') END AS tgt_table,   -- от "." до конца строки 
       CASE WHEN POSITION ('.' IN COALESCE(tt.src_table, '~')) > 0 THEN substring(COALESCE(tt.src_table, '~') , 1 , POSITION ('.' IN COALESCE(tt.src_table, '~')) - 1 )  ELSE COALESCE(tt.src_schema, '~') END AS src_schema, -- от начала до "."
       CASE WHEN POSITION ('.' IN COALESCE(tt.tgt_table, '~')) > 0 THEN substring(COALESCE(tt.tgt_table, '~') , 1 , POSITION ('.' IN COALESCE(tt.tgt_table, '~')) + 1 )  ELSE COALESCE(tt.tgt_schema, '~') END AS tgt_schema, -- от начала до "."
       COALESCE(tt.entity, '~') AS entity,
       COALESCE(tt.wf_time_sched, '~') AS wf_time_sched,
       COALESCE(tt.wf_event_sched, '~') AS wf_event_sched,
       COALESCE(tt.wf_event_sched_str, '~') AS wf_event_sched_str,
       COALESCE(tt.cron_schedule, '~') AS cron_schedule 
       FROM tt
   DISTRIBUTED BY (wf_name);
   RAISE NOTICE 'temp_ctl';

CREATE TEMPORARY TABLE temp_schema AS
WITH tt AS (
SELECT 
t.category AS schema_src_id ,
t.category AS schema_cd, 
t.category AS descr,
'ПРОМ' AS type,
'Cathegory' AS schema_type,
current_timestamp AS load_dttm,
-1::int4 AS wf_load_id,
'CTL' AS src_cd
FROM temp_json t
UNION
SELECT 
CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS schema_src_id ,
CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS schema_cd ,
CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS descr,
'ПРОМ' AS type,
'Schema' AS schema_type,
current_timestamp AS load_dttm,
-1::int4 AS wf_load_id,
'GP' AS src_cd
FROM temp_json t
UNION
SELECT 
CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS schema_src_id,
CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS schema_cd,
CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS descr,
'ПРОМ' AS type,
'Schema' AS schema_type,
current_timestamp AS load_dttm,
-1::int4 AS wf_load_id,
'GP' AS src_cd
FROM temp_json t
)
SELECT DISTINCT  
tt.schema_src_id,
tt.schema_cd, 
tt.descr,
tt.type,
tt.schema_type,
tt.load_dttm,
tt.wf_load_id,
tt.src_cd
FROM tt
WHERE 1=1
AND tt.schema_src_id IS NOT NULL
DISTRIBUTED BY (schema_src_id);
RAISE NOTICE 'temp_schema';

CREATE TEMPORARY TABLE temp_json_det AS
   WITH temp_main AS (
   SELECT 
       j.wf_name        ,
       j.category       ,
       CASE WHEN j.src_table IN ('null') THEN NULL ELSE j.src_table END AS src_table,
       CASE WHEN j.tgt_table IN ('null') THEN NULL ELSE j.tgt_table END AS tgt_table, 
       CASE WHEN j.src_schema IN ('null') THEN NULL ELSE j.src_schema END AS src_schema,
       CASE WHEN j.tgt_schema IN ('null') THEN NULL ELSE j.tgt_schema END AS tgt_schema,
       CASE WHEN j.entity IN ('null') THEN NULL ELSE j.entity END AS entity,
       CASE WHEN j.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE j.wf_time_sched END AS wf_time_sched,
       j.cron_schedule,
       UNNEST(string_to_array(REPLACE(REPLACE(j.wf_event_sched,'[',''),']',''),',')) AS wf_event_sched    
   FROM temp_json j
   WHERE j.wf_event_sched NOT IN ('null','[]')
   UNION
   SELECT 
       j.wf_name        ,
       j.category       ,
       CASE WHEN j.src_table IN ('null') THEN NULL ELSE j.src_table END AS src_table,
       CASE WHEN j.tgt_table IN ('null') THEN NULL ELSE j.tgt_table END AS tgt_table, 
       CASE WHEN j.src_schema IN ('null') THEN NULL ELSE j.src_schema END AS src_schema,
       CASE WHEN j.tgt_schema IN ('null') THEN NULL ELSE j.tgt_schema END AS tgt_schema,
       CASE WHEN j.entity IN ('null') THEN NULL ELSE j.entity END AS entity,
       CASE WHEN j.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE j.wf_time_sched END AS wf_time_sched,
       j.cron_schedule,
       NULL AS wf_event_sched
   FROM temp_json j
   WHERE j.wf_event_sched IN ('null','[]')
   )
   , temp_espd AS (
   SELECT  t.wf_name AS espd_wf_name,
           t.category AS espd_category,
           CASE WHEN t.entity IN ('null') THEN NULL ELSE t.entity END AS espd_entity,
           CASE WHEN t.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE t.wf_time_sched END AS espd_wf_time_sched,
           t.cron_schedule AS espd_cron_schedule
   FROM temp_json t
   WHERE 1=1
    AND t.category like '%espd%'
  )
   SELECT 
       COALESCE(m.wf_name, '~') AS wf_name,
       COALESCE(m.category, '~') AS category,
       COALESCE(m.src_table, '~') AS src_table,
       COALESCE(m.tgt_table, '~') AS  tgt_table, 
       COALESCE(m.src_schema, '~') AS src_schema,
       COALESCE(m.tgt_schema, '~') AS tgt_schema,
       COALESCE(m.entity, '~') AS entity,
       COALESCE(m.wf_time_sched, '~') AS wf_time_sched,
       COALESCE(m.wf_event_sched, '~') AS wf_event_sched,
       COALESCE(m.cron_schedule, '~') AS cron_schedule, 
       COALESCE(e.espd_wf_name, '~') AS espd_wf_name,
       COALESCE(e.espd_category, '~') AS espd_category,
       COALESCE(e.espd_entity, '~') AS espd_entity,
       COALESCE(e.espd_wf_time_sched, '~') AS espd_wf_time_sched,
       COALESCE(e.espd_cron_schedule, '~') AS espd_cron_schedule,
       CASE WHEN  m.wf_event_sched IS NOT NULL AND e.espd_wf_name IS NULL THEN 0   -- заполняем только часть src->CTL->tgt + указываем на отсутствие объекта 
            WHEN  m.wf_event_sched IS NULL THEN 2 -- заполняем только часть src->CTL->tgt 
            ELSE 1                                -- заполняем ESPD->src->CTL->tgt
       END AS fl_ins 
   FROM temp_main m
   LEFT JOIN temp_espd e ON m.wf_event_sched = e.espd_entity
   WHERE 1=1
     AND m.category NOT LIKE '%espd%'
   DISTRIBUTED BY (wf_name);
   RAISE NOTICE 'temp_json_det';

  v_res_schema := '';
  FOR rec IN (SELECT s.* 
              FROM temp_schema s ORDER BY s.schema_src_id) 
  LOOP
    -- Проверяем наличие и Заполняем meta_schema_ref_table
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_schema_ref_table
        WHERE 1=1
            AND schema_src_id = ''' || rec.schema_src_id || '''' ||
          ' AND src_cd = ''' || rec.src_cd || ''''
        INTO v_cnt;

        IF COALESCE(v_cnt,0) = 0 THEN
          v_res_schema := v_res_schema || 
          ('INSERT INTO '|| p_out_schema || '.meta_schema_ref_table ( schema_src_id,schema_cd,descr,type,schema_type,load_dttm,wf_load_id,src_cd )
            VALUES ( '''    ||
               rec.schema_src_id  || ''',''' ||
               rec.schema_cd  || ''',''' ||
               rec.descr  || ''',''' ||
               rec.type  || ''',''' ||
               rec.schema_type || ''', current_timestamp, ' ||
               p_wf_load_id || ', ''' ||
               rec.src_cd  || '''); ')::TEXT  || chr(10);
          RAISE NOTICE 'v_res_schema - %', v_res_schema::TEXT;
        END IF;
    
  END LOOP;
  
  v_res_node := '';
  v_res_sched := '';
  -- Отбираем объекты ESPD, т.к. на них строятся зависимости
  FOR rec IN (SELECT * FROM temp_espd) 
  LOOP
        RAISE NOTICE '%.meta_node_ref_table', p_out_schema::TEXT;

    -- Проверяем наличие и Заполняем meta_node_ref_table
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_node_ref_table
        WHERE 1=1
            AND node_src_id = '''   || rec.wf_name  || '''' ||
          ' AND schema_src_id = ''' || rec.category || '''' ||
          ' AND src_cd = ''CTL'''
        INTO v_cnt;
  
        IF COALESCE(v_cnt,0) = 0 THEN
          v_res_node := v_res_node || 
          ('INSERT INTO '|| p_out_schema || '.meta_node_ref_table (node_src_id, schema_src_id, load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,node_cd,node_name,node_type_src_id,is_active,created_dt,modified_dt)
            VALUES ( '''    ||
               rec.wf_name  || ''',''' ||
               rec.category || ''', current_timestamp, ''CTL'',' ||
               p_wf_load_id || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
               rec.wf_name  || ''',''' ||
               rec.wf_name  || ''',9, ''TRUE''::bool, current_timestamp, current_timestamp); ')::TEXT  || chr(10);
        END IF;
        RAISE NOTICE 'v_res_node - %', v_res_node::TEXT;
    
        -- Проверяем наличие и Заполняем расписание meta_scheduler_hsat
        EXECUTE 'SELECT count(*)
        FROM '|| p_out_schema || '.meta_scheduler_hsat sch 
        WHERE 1=1
            AND sch.node_src_id = '''   || rec.wf_name  || '''' ||
          ' AND sch.schema_src_id = ''' || rec.category || '''' ||
          ' AND sch.src_cd = ''CTL'''
          INTO v_cnt;
      
        EXECUTE 'SELECT '|| p_out_schema || '.meta_is_wellformed( ''' || rec.wf_time_sched || ''')' INTO v_cron;
    
        IF rec.cron_schedule  = 'true' AND v_cron = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.wf_name || ''',''' || rec.wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        
        IF COALESCE(v_cnt,0) = 0 THEN
        
           RAISE NOTICE 'v_res_sched - INSERT %, %', v_res_sched::TEXT, COALESCE(v_cnt,0)::TEXT;
    
           v_scheduler_id := nextval(p_out_schema || '.synth_key_seq');
    
           v_res_sched := v_res_sched ||     
           ('INSERT INTO '|| p_out_schema || '.meta_scheduler_hsat (
           scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
           node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
           node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
           VALUES ('          || 
           v_scheduler_id     || ', current_timestamp, ''CTL''::varchar(20),' ||
           p_wf_load_id       || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
           rec.wf_name        || ''',''' ||
           rec.category       || ''', ''Auto''::varchar(250), 1, 1, ''' ||
           rec.wf_time_sched  || ''',''' ||
           rec.wf_event_sched || ''',''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        
           RAISE NOTICE 'v_res_sched - UPDATE %, %', v_res_sched::TEXT, COALESCE(v_cnt,0)::TEXT;

           v_res_sched := v_res_sched ||     
           ('UPDATE ' || p_out_schema || '.meta_scheduler_hsat
           SET
                period_type_comment = '''    || rec.wf_time_sched  || ''',' || 
               'period_refresh_comment = ''' || rec.wf_event_sched || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
           WHERE 1=1
               AND node_src_id = '''   || rec.wf_name  || '''' || 
             ' AND schema_src_id = ''' || rec.category || '''' ||
             ' AND src_cd = ''CTL''; ')::TEXT || chr(10);
        END IF;
  END LOOP;            
   
   -- Отбираем объекты CTL
  v_res_edge := '';
  FOR rec IN (SELECT * FROM temp_ctl) 
  LOOP
        -- В объектах CTL получаем объекты SRC и TGT. Их наличие проверяем в метаданных GP
        EXECUTE 'SELECT count(*)
        FROM ' || p_out_schema || '.vmeta_node_ref_table nd
        WHERE 1=1
            AND (nd.node_src_id = '''  || rec.src_table || ''' OR nd.node_src_id = ''' || rec.src_table || '_actrepl'' OR nd.node_src_id = ''' || rec.src_table || '_inc'')' ||
          ' AND nd.schema_src_id = ''' || rec.src_schema || '''' 
        INTO v_cnt;
    
        IF COALESCE(v_cnt,0) = 0 THEN
           v_res_node := v_res_node || '-- ''' || rec.src_schema || '''.''' || rec.src_table || ''':таблица-источник не валидная' || chr(10);
        END IF;
    
        EXECUTE 'SELECT count(*) 
        FROM ' || p_out_schema || '.vmeta_node_ref_table nd
        WHERE 1=1
            AND (nd.node_src_id = '''  || rec.tgt_table || ''' OR nd.node_src_id = ''' || rec.tgt_table || '_actrepl'' OR nd.node_src_id = ''' || rec.tgt_table || '_inc'')' ||
          ' AND nd.schema_src_id = ''' || rec.tgt_schema || '''' 
        INTO v_cnt;
    
        IF COALESCE(v_cnt,0) = 0 THEN
           v_res_node := v_res_node || '-- ''' || rec.tgt_schema || '''.''' || rec.tgt_table || ''':таблица-приемник не валидная' || chr(10);
        END IF;
  
        -- Проверяем наличие и Заполняем meta_node_ref_table
        EXECUTE 'SELECT count(*) 
        FROM ' || p_out_schema || '.meta_node_ref_table nd
        WHERE 1=1
            AND nd.node_src_id = '''   || rec.wf_name || '''' ||
          ' AND nd.schema_src_id = ''' || rec.category || '''' ||
          ' AND nd.src_cd = ''CTL'''
        INTO v_cnt;
    
        IF COALESCE(v_cnt,0) = 0 THEN
          v_res_node := v_res_node || 
          ('INSERT INTO ' || p_out_schema || '.meta_node_ref_table (node_src_id, schema_src_id, load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,node_cd,node_name,node_type_src_id,is_active,created_dt,modified_dt)
            VALUES ( '''    ||
               rec.wf_name  || ''',''' ||
               rec.category || ''', current_timestamp, ''CTL'',' ||
               p_wf_load_id || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
               rec.wf_name  || ''', ''' ||
               rec.wf_name  || ''',5 , ''TRUE''::bool, current_timestamp, current_timestamp); ')::TEXT  || chr(10);
        END IF;
        RAISE NOTICE 'v_res_node - %', v_res_node::TEXT;
    
        -- Проверяем наличие и Заполняем расписание meta_scheduler_hsat
        EXECUTE 'SELECT count(*) 
        FROM ' || p_out_schema || '.meta_scheduler_hsat sch 
        WHERE 1=1
            AND sch.node_src_id = '''   || rec.wf_name  || '''' ||
          ' AND sch.schema_src_id = ''' || rec.category || '''' ||
          ' AND sch.src_cd = ''CTL'''
        INTO v_cnt;
      
        EXECUTE 'SELECT '|| p_out_schema || '.meta_is_wellformed( ''' || rec.wf_time_sched || ''')' INTO v_cron;
    
        IF rec.cron_schedule  = 'true' AND v_cron = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.wf_name || ''',''' || rec.wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
    
        IF COALESCE(v_cnt,0) = 0 THEN  
        v_scheduler_id := nextval(p_out_schema || '.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO ' || p_out_schema || '.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('              || 
        v_scheduler_id         || ', current_timestamp, ''CTL''::varchar(20),' ||
        p_wf_load_id           || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.wf_name            || ''',''' ||
        rec.category           || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.wf_time_sched      || ''',''' ||
        rec.wf_event_sched_str || ''',''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        v_res_sched := v_res_sched ||     
        ('UPDATE ' || p_out_schema || '.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.wf_time_sched || ''',' || 
            'period_refresh_comment = ''' || rec.wf_event_sched_str || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.wf_name  || '''' || 
          ' AND schema_src_id = ''' || rec.category || '''' ||
          ' AND src_cd = ''CTL''; ')::TEXT || chr(10);
    END IF;
    RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
  END LOOP;
  
  -- Расписание дублируем у таблиц по CTL объектам - SRC
  FOR rec IN ( SELECT DISTINCT  
                        jd.src_table,
                        jd.src_schema,
                        jd.espd_wf_time_sched,
                        jd.espd_cron_schedule,
                        jd.tgt_table,
                        jd.tgt_schema,
                        jd.wf_time_sched,
                        jd.cron_schedule
               FROM temp_json_det jd 
               WHERE 1 = 1
                 AND jd.src_table <> '~'
                 AND jd.src_schema <> '~'
                 AND jd.tgt_table <> '~'
                 AND jd.tgt_schema <> '~'
                 AND jd.espd_wf_time_sched <> '~'
                 AND jd.wf_time_sched <> '~'
              ) LOOP
              
        EXECUTE 'SELECT count(*) 
        FROM '|| p_out_schema || '.meta_scheduler_hsat sch 
        WHERE 1=1
            AND sch.node_src_id = '''   || rec.src_table  || '''' ||
          ' AND sch.schema_src_id = ''' || rec.src_schema || '''' ||
          ' AND sch.src_cd = ''GP'''
        INTO v_cnt;
      
        EXECUTE 'SELECT '|| p_out_schema || '.meta_is_wellformed( ''' || rec.espd_wf_time_sched || ''')' INTO v_cron;
    
        IF rec.cron_schedule  = 'true' AND v_cron = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.src_table || ''',''' || rec.espd_wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
    
        IF COALESCE(v_cnt,0) = 0 THEN  
        v_scheduler_id := nextval(p_out_schema || '.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO ' || p_out_schema || '.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('              || 
        v_scheduler_id         || ', current_timestamp, ''GP''::varchar(20),' ||
        p_wf_load_id           || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.src_table          || ''',''' ||
        rec.src_schema         || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.espd_wf_time_sched || ''',NULL::TEXT,''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        v_res_sched := v_res_sched ||     
        ('UPDATE ' || p_out_schema || '.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.espd_wf_time_sched || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.src_table  || '''' || 
          ' AND schema_src_id = ''' || rec.src_schema || '''' ||
          ' AND src_cd = ''GP''; ')::TEXT || chr(10);
    END IF;
    RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
         
        -- Расписание дублируем у таблиц по CTL объектам - TGT
        EXECUTE 'SELECT count(*) 
        FROM ' || p_out_schema || '.meta_scheduler_hsat sch 
        WHERE 1=1
            AND sch.node_src_id = '''   || rec.tgt_table  || '''' ||
          ' AND sch.schema_src_id = ''' || rec.tgt_schema || '''' ||
          ' AND sch.src_cd = ''GP'''
        INTO v_cnt;
      
        EXECUTE 'SELECT '|| p_out_schema || '.meta_is_wellformed( ''' || rec.wf_time_sched || ''')' INTO v_cron;
    
        IF rec.cron_schedule  = 'true' AND v_cron = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.tgt_table || ''',''' || rec.wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
    
        IF COALESCE(v_cnt,0) = 0 THEN  
        v_scheduler_id := nextval(p_out_schema || '.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO ' || p_out_schema || '.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('              || 
        v_scheduler_id         || ', current_timestamp, ''GP''::varchar(20),' ||
        p_wf_load_id           || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.tgt_table          || ''',''' ||
        rec.tgt_schema         || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.wf_time_sched      || ''',''' ||
        '{''''wf_event_sched'''': [] }' || ''',''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        v_res_sched := v_res_sched ||     
        ('UPDATE ' || p_out_schema || '.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.wf_time_sched || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.tgt_table  || '''' || 
          ' AND schema_src_id = ''' || rec.tgt_schema || '''' ||
          ' AND src_cd = ''GP''; ')::TEXT || chr(10);
    END IF;
    RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
  END LOOP;

  -- Связи между объектами espd_wf -> src_table -> ctl_wf ->  tgt_table
  FOR rec IN ( SELECT *   FROM temp_json_det jd) LOOP
     IF rec.fl_ins = 1 THEN 
        -- espd_wf_name as src_node
        -- espd_category as src_schema
        -- src_table as tgt_node
        -- src_schema as tgt_schema
        -- Проверяем наличие и Заполняем meta_edge_link
        EXECUTE 'SELECT count(*)
        FROM ' || p_out_schema || '.meta_edge_link e
        WHERE 1=1
            AND e.src_node_src_id = '''      || rec.espd_wf_name  || '''' ||
          ' AND e.src_schema_src_id = '''    || rec.espd_category || '''' ||
          ' AND e.target_node_src_id = '''   || rec.src_table     || '''' ||
          ' AND e.target_schema_src_id = ''' || rec.src_schema    || ''''
        INTO v_cnt;
      
        IF rec.espd_wf_name IS NULL THEN
           v_res_edge := v_res_edge || '''' || rec.espd_wf_name || ''':не найден объект espd' || chr(10); --     
        END IF;

       IF rec.espd_wf_name IS NOT NULL AND COALESCE(v_cnt,0) = 0 THEN
          v_edge_id := nextval(p_out_schema || '.synth_key_seq');

          v_res_edge := v_res_edge || 
          ('INSERT INTO ' || p_out_schema || '.meta_edge_link (edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,
                        src_node_src_id,src_schema_src_id,
                        target_node_src_id,target_schema_src_id,
                        edge_type_src_id,property_id,weight,order_by,is_active)
            VALUES ( '    ||
               v_edge_id || ', current_timestamp, ''GP'', -1, ''1900-01-01''::date, ''2999-12-31''::date,current_timestamp, ''' ||
               rec.espd_wf_name  || ''',''' ||
               rec.espd_category || ''',''' ||
               rec.src_table     || ''',''' ||
               rec.src_schema    || ''',' ||
               '1 ,-1 ,1 ,1 ,TRUE::bool);')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_edge - %', v_res_edge::TEXT;
   END IF;
   -- связи только для src->CTL->tgt
   IF rec.fl_ins IN (0,1,2) THEN 
   -- src_tabe as src_node
   -- src_schema as src_schema
   -- wf_name as tgt_node
   -- category as tgt_schema
        -- Проверяем наличие и Заполняем meta_edge_link
        EXECUTE ' SELECT count(*) 
        FROM ' || p_out_schema || '.meta_edge_link e
        WHERE 1=1
            AND e.src_node_src_id = '''      || rec.src_table  || '''' ||
          ' AND e.src_schema_src_id = '''    || rec.src_schema || '''' ||
          ' AND e.target_node_src_id = '''   || rec.wf_name    || '''' ||
          ' AND e.target_schema_src_id = ''' || rec.category   || ''''
       INTO v_cnt;
      
       IF COALESCE(v_cnt,0) = 0 THEN
          v_edge_id := nextval(p_out_schema || '.synth_key_seq');

          v_res_edge := v_res_edge || 
          ('INSERT INTO ' || p_out_schema || '.meta_edge_link (edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,
                        src_node_src_id,src_schema_src_id,
                        target_node_src_id,target_schema_src_id,
                        edge_type_src_id,property_id,weight,order_by,is_active)
            VALUES ( '    ||
               v_edge_id || ', current_timestamp, ''GP'', -1, ''1900-01-01''::date, ''2999-12-31''::date,current_timestamp, ''' ||
               rec.src_table  || ''',''' ||
               rec.src_schema || ''',''' ||
               rec.wf_name    || ''',''' ||
               rec.category   || ''',' ||
               '1 ,-1 ,1 ,1 ,TRUE::bool);')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_edge - %', v_res_edge::TEXT;
   
        -- wf_name as src_node
        -- category as src_schema
        -- tgt_table as tgt_node
        -- tgt_schema as tgt_schema
        -- Проверяем наличие и Заполняем meta_edge_link
        EXECUTE 'SELECT count(*) 
        FROM ' || p_out_schema || '.meta_edge_link e
        WHERE 1=1
            AND e.src_node_src_id = '''      || rec.wf_name    || '''' ||
          ' AND e.src_schema_src_id = '''    || rec.category   || '''' ||
          ' AND e.target_node_src_id = '''   || rec.tgt_table  || '''' ||
          ' AND e.target_schema_src_id = ''' || rec.tgt_schema || '''' 
       INTO v_cnt;
      
       IF COALESCE(v_cnt,0) = 0 THEN
          v_edge_id := nextval(p_out_schema || '.synth_key_seq');

          v_res_edge := v_res_edge || 
          ('INSERT INTO ' || p_out_schema || '.meta_edge_link (edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,
                        src_node_src_id,src_schema_src_id,
                        target_node_src_id,target_schema_src_id,
                        edge_type_src_id,property_id,weight,order_by,is_active)
            VALUES ( '    ||
               v_edge_id || ', current_timestamp, ''GP'', -1, ''1900-01-01''::date, ''2999-12-31''::date,current_timestamp, ''' ||
               rec.wf_name || ''',''' ||
               rec.category || ''',''' ||
               rec.tgt_table || ''',''' ||
               rec.tgt_schema  || ''',' ||
               '1 ,-1 ,1 ,1 ,TRUE::bool);')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_edge - %', v_res_edge::TEXT;
    END IF;
    -- список не найденных объектов
    IF rec.fl_ins = 0 THEN 
        v_res_edge := v_res_edge || '--''' || rec.wf_name || ''',''' || rec.wf_event_sched || ''' : не найдена ссылка на espd объект' || chr(10); --  не найдена ссылка на espd объект    
    END IF;

   END LOOP;
----------------------------------------------------------------------------------------------------
  
    DROP TABLE temp_json;
    DROP TABLE temp_espd;
    DROP TABLE temp_ctl;
    DROP TABLE temp_schema;
    DROP TABLE temp_json_det;

    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_parse_json'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN COALESCE(v_res_schema,'~') || chr(10) ||
           COALESCE(v_res_node,'~') || chr(10) ||
           COALESCE(v_res_sched,'~')  || chr(10) ||
           COALESCE(v_res_edge,'~');

    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_parse_json'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;









$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_parse_json(p_json json, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
/* Change Log 
 * FVV Формат json
*  
*/   
      
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    v_scheduler_id   bpchar(10);
    v_edge_id        bpchar(10);
    v_cnt            int4;
    v_cnt_sch        int4;
    v_cnt_tbl        int4;
    rec              record;
    v_json           json;
    v_res_node  TEXT DEFAULT '';
    v_res_sched TEXT DEFAULT '';
    v_res_edge  TEXT DEFAULT '';
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );

    RAISE NOTICE 'input, %', p_json;

    v_json := replace(replace(p_json,'''''','"null"'), '''', '"');
    --v_json := p_json;

    CREATE TEMPORARY TABLE temp_json AS
    SELECT *
    FROM json_populate_recordset(NULL::record, v_json::json)
    AS (
       wf_name        TEXT,
       category       TEXT,
       src_table      TEXT,
       tgt_table      TEXT, 
       src_schema     TEXT,
       tgt_schema     TEXT,
       entity         TEXT,
       wf_time_sched  TEXT,
       wf_event_sched TEXT  
       )
   DISTRIBUTED BY (wf_name);
   
CREATE TEMPORARY TABLE temp_espd AS
WITH tt AS (
SELECT t.wf_name,
       t.category,
       CASE WHEN t.src_table IN ('null') THEN NULL ELSE t.src_table END AS src_table,
       CASE WHEN t.tgt_table IN ('null') THEN NULL ELSE t.tgt_table END AS tgt_table, 
       CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS src_schema,
       CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS tgt_schema,
       CASE WHEN t.entity IN ('null') THEN NULL ELSE t.entity END AS entity,
       CASE WHEN t.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE t.wf_time_sched END AS wf_time_sched,
       CASE WHEN t.wf_event_sched IN ('null','[]') THEN 'espd' ELSE t.wf_event_sched END AS wf_event_sched
               FROM temp_json t
               WHERE 1=1
               AND t.category = 'ts_espd'
   )
   SELECT
       COALESCE(tt.wf_name,'~') AS wf_name,
       COALESCE(tt.category,'~') AS category,
       COALESCE(tt.src_table,'~') AS src_table,
       COALESCE(tt.tgt_table,'~') AS tgt_table, 
       COALESCE(tt.src_schema,'~') AS src_schema,
       COALESCE(tt.tgt_schema,'~') AS tgt_schema,
       COALESCE(tt.entity,'~') AS entity,
       COALESCE(tt.wf_time_sched,'~') AS wf_time_sched,
       COALESCE(tt.wf_event_sched,'~') AS wf_event_sched 
       FROM tt
   DISTRIBUTED BY (wf_name);
               
CREATE TEMPORARY TABLE temp_ctl AS
WITH tt AS (
SELECT t.wf_name,
       t.category,
       CASE WHEN t.src_table IN ('null') THEN NULL ELSE t.src_table END AS src_table,
       CASE WHEN t.tgt_table IN ('null') THEN NULL ELSE t.tgt_table END AS tgt_table, 
       CASE WHEN t.src_schema IN ('null') THEN NULL ELSE t.src_schema END AS src_schema,
       CASE WHEN t.tgt_schema IN ('null') THEN NULL ELSE t.tgt_schema END AS tgt_schema,
       CASE WHEN t.entity IN ('null') THEN NULL ELSE t.entity END AS entity,
       CASE WHEN t.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE t.wf_time_sched END AS wf_time_sched,
       CASE WHEN t.wf_event_sched IN ('null','[]') THEN 'ctl' ELSE t.wf_event_sched END AS wf_event_sched,
       CASE WHEN t.wf_event_sched IN ('null','[]') THEN 'ctl' ELSE '{''''wf_event_sched'''': ' || CASE WHEN t.wf_event_sched IN ('null','[]') THEN 'ctl' ELSE t.wf_event_sched END || '}' END AS wf_event_sched_str
               FROM temp_json t
               WHERE 1=1
               AND t.category <> 'ts_espd'
    )
    SELECT
       COALESCE(tt.wf_name, '~') AS wf_name,
       COALESCE(tt.category, '~') AS category,
       COALESCE(tt.src_table, '~') AS src_table,
       COALESCE(tt.tgt_table, '~') AS tgt_table,  
       COALESCE(tt.src_schema, '~') AS src_schema,
       COALESCE(tt.tgt_schema, '~') AS tgt_schema,
       COALESCE(tt.entity, '~') AS entity,
       COALESCE(tt.wf_time_sched, '~') AS wf_time_sched,
       COALESCE(tt.wf_event_sched, '~') AS wf_event_sched,
       COALESCE(tt.wf_event_sched_str, '~') AS wf_event_sched_str 
       FROM tt
   DISTRIBUTED BY (wf_name);
   
   CREATE TEMPORARY TABLE temp_json_det AS
   WITH temp_main AS (
   SELECT 
       j.wf_name        ,
       j.category       ,
       CASE WHEN j.src_table IN ('null') THEN NULL ELSE j.src_table END AS src_table,
       CASE WHEN j.tgt_table IN ('null') THEN NULL ELSE j.tgt_table END AS tgt_table, 
       CASE WHEN j.src_schema IN ('null') THEN NULL ELSE j.src_schema END AS src_schema,
       CASE WHEN j.tgt_schema IN ('null') THEN NULL ELSE j.tgt_schema END AS tgt_schema,
       CASE WHEN j.entity IN ('null') THEN NULL ELSE j.entity END AS entity,
       CASE WHEN j.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE j.wf_time_sched END AS wf_time_sched,
       UNNEST(string_to_array(REPLACE(REPLACE(j.wf_event_sched,'[',''),']',''),',')) AS wf_event_sched    
   FROM temp_json j
   WHERE j.wf_event_sched NOT IN ('null','[]')
   UNION
   SELECT 
       j.wf_name        ,
       j.category       ,
       CASE WHEN j.src_table IN ('null') THEN NULL ELSE j.src_table END AS src_table,
       CASE WHEN j.tgt_table IN ('null') THEN NULL ELSE j.tgt_table END AS tgt_table, 
       CASE WHEN j.src_schema IN ('null') THEN NULL ELSE j.src_schema END AS src_schema,
       CASE WHEN j.tgt_schema IN ('null') THEN NULL ELSE j.tgt_schema END AS tgt_schema,
       CASE WHEN j.entity IN ('null') THEN NULL ELSE j.entity END AS entity,
       CASE WHEN j.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE j.wf_time_sched END AS wf_time_sched,
       NULL AS wf_event_sched
   FROM temp_json j
   WHERE j.wf_event_sched IN ('null','[]')
   )
   , temp_espd AS (
   SELECT  t.wf_name AS espd_wf_name,
           t.category AS espd_category,
           CASE WHEN t.entity IN ('null') THEN NULL ELSE t.entity END AS espd_entity,
           CASE WHEN t.wf_time_sched IN ('null') THEN '0 12 * * 1-5' ELSE t.wf_time_sched END AS espd_wf_time_sched
   FROM temp_json t
   WHERE 1=1
    AND t.category = 'ts_espd'
  )
   SELECT 
       COALESCE(m.wf_name, '~') AS wf_name,
       COALESCE(m.category, '~') AS category,
       COALESCE(m.src_table, '~') AS src_table,
       COALESCE(m.tgt_table, '~') AS  tgt_table, 
       COALESCE(m.src_schema, '~') AS src_schema,
       COALESCE(m.tgt_schema, '~') AS tgt_schema,
       COALESCE(m.entity, '~') AS entity,
       COALESCE(m.wf_time_sched, '~') AS wf_time_sched,
       COALESCE(m.wf_event_sched, '~') AS wf_event_sched,
       COALESCE(e.espd_wf_name, '~') AS espd_wf_name,
       COALESCE(e.espd_category, '~') AS espd_category,
       COALESCE(e.espd_entity, '~') AS espd_entity,
       COALESCE(e.espd_wf_time_sched, '~') AS espd_wf_time_sched,
       CASE WHEN  m.wf_event_sched IS NOT NULL AND e.espd_wf_name IS NULL THEN 0   -- заполняем только часть src->CTL->tgt + указываем на отсутствие объекта 
            WHEN  m.wf_event_sched IS NULL THEN 2 -- заполняем только часть src->CTL->tgt 
            ELSE 1                                -- заполняем ESPD->src->CTL->tgt
       END AS fl_ins 
   FROM temp_main m
   LEFT JOIN temp_espd e ON m.wf_event_sched = e.espd_entity
   WHERE 1=1
     AND m.category <> 'ts_espd'
   DISTRIBUTED BY (wf_name);
   
  v_res_node := '';
  v_res_sched := '';
  -- Отбираем объекты ESPD, т.к. на них строятся зависимости
  FOR rec IN (SELECT * FROM temp_espd) 
  LOOP
        -- Проверяем наличие и Заполняем meta_node_ref_table
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_node_ref_table nd
        WHERE 1=1
          AND nd.node_src_id = rec.wf_name
          AND nd.schema_src_id = rec.category
          AND nd.src_cd = 'CTL';
      
        IF COALESCE(v_cnt,0) = 0 THEN
          v_res_node := v_res_node || 
          ('INSERT INTO dg_full.meta_node_ref_table (node_src_id, schema_src_id, load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,node_cd,node_name,node_type_src_id,is_active,created_dt,modified_dt)
            VALUES ( '''    ||
               rec.wf_name  || ''',''' ||
               rec.category || ''', current_timestamp, ''CTL'',' ||
               p_wf_load_id || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
               rec.wf_name  || ''',''' ||
               rec.wf_name  || ''',9, ''TRUE''::bool, current_timestamp, current_timestamp); ')::TEXT  || chr(10);
        END IF;
        RAISE NOTICE 'v_res_node - %', v_res_node::TEXT;
    
        -- Проверяем наличие и Заполняем расписание meta_scheduler_hsat
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_scheduler_hsat sch 
        WHERE 1=1
          AND sch.node_src_id = rec.wf_name
          AND sch.schema_src_id = rec.category
          AND sch.src_cd = 'CTL';
      
        IF rec.wf_time_sched IS NOT NULL AND dg_full.meta_is_wellformed(rec.wf_time_sched) = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.wf_name || ''',''' || rec.wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        
        RAISE NOTICE 'v_res_sched - %, %', v_res_sched::TEXT, COALESCE(v_cnt,0)::TEXT;
        IF COALESCE(v_cnt,0) = 0 THEN
        
        RAISE NOTICE 'v_res_sched - %, %', v_res_sched::TEXT, COALESCE(v_cnt,0)::TEXT;
    
        v_scheduler_id := nextval('dg_full.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO dg_full.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('          || 
        v_scheduler_id     || ', current_timestamp, ''CTL''::varchar(20),' ||
        p_wf_load_id       || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.wf_name        || ''',''' ||
        rec.category       || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.wf_time_sched  || ''',''' ||
        rec.wf_event_sched || ''',''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        
        RAISE NOTICE 'v_res_sched - %, %', v_res_sched::TEXT, COALESCE(v_cnt,0)::TEXT;

        v_res_sched := v_res_sched ||     
        ('UPDATE dg_full.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.wf_time_sched  || ''',' || 
            'period_refresh_comment = ''' || rec.wf_event_sched || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.wf_name  || '''' || 
          ' AND schema_src_id = ''' || rec.category || '''' ||
          ' AND src_cd = ''CTL''; ')::TEXT || chr(10);
    END IF;
  END LOOP;            
   
   -- Отбираем объекты CTL
  v_res_edge := '';
  FOR rec IN (SELECT * FROM temp_ctl) 
  LOOP
        -- В объектах CTL получаем объекты SRC и TGT. Их наличие проверяем в метаданных GP
        SELECT count(*) INTO v_cnt
        FROM dg_full.vmeta_node_ref_table nd
        WHERE 1=1
          AND nd.node_src_id = rec.src_table
          AND nd.schema_src_id = rec.src_schema;
        IF COALESCE(v_cnt,0) = 0 THEN
           v_res_node := v_res_node || '''' || rec.src_table || ''':таблица-источник не валидная' || chr(10);
        END IF;
    
        SELECT count(*) INTO v_cnt
        FROM dg_full.vmeta_node_ref_table nd
        WHERE 1=1
          AND nd.node_src_id = rec.tgt_table
          AND nd.schema_src_id = rec.tgt_schema;
        IF COALESCE(v_cnt,0) = 0 THEN
           v_res_node := v_res_node || '''' || rec.tgt_table || ''':таблица-приемник не валидная' || chr(10);
        END IF;
  
        -- Проверяем наличие и Заполняем meta_node_ref_table
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_node_ref_table nd
        WHERE 1=1
          AND nd.node_src_id = rec.wf_name
          AND nd.schema_src_id = rec.category
          AND nd.src_cd = 'CTL';
      
        IF COALESCE(v_cnt,0) = 0 THEN
          v_res_node := v_res_node || 
          ('INSERT INTO dg_full.meta_node_ref_table (node_src_id, schema_src_id, load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,node_cd,node_name,node_type_src_id,is_active,created_dt,modified_dt)
            VALUES ( '''    ||
               rec.wf_name  || ''',''' ||
               rec.category || ''', current_timestamp, ''CTL'',' ||
               p_wf_load_id || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
               rec.wf_name  || ''', ''' ||
               rec.wf_name  || ''',5 , ''TRUE''::bool, current_timestamp, current_timestamp); ')::TEXT  || chr(10);
        END IF;
        RAISE NOTICE 'v_res_node - %', v_res_node::TEXT;
    
        -- Проверяем наличие и Заполняем расписание meta_scheduler_hsat
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_scheduler_hsat sch 
        WHERE 1=1
          AND sch.node_src_id = rec.wf_name
          AND sch.schema_src_id = rec.category
          AND sch.src_cd = 'CTL';
      
        IF rec.wf_time_sched IS NOT NULL AND dg_full.meta_is_wellformed(rec.wf_time_sched) = FALSE THEN
           v_res_sched := v_res_sched || '''' || rec.wf_name || ''',''' || rec.wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
    
        IF COALESCE(v_cnt,0) = 0 THEN  
        v_scheduler_id := nextval('dg_full.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO dg_full.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('              || 
        v_scheduler_id         || ', current_timestamp, ''CTL''::varchar(20),' ||
        p_wf_load_id           || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.wf_name            || ''',''' ||
        rec.category           || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.wf_time_sched      || ''',''' ||
        rec.wf_event_sched_str || ''',''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        v_res_sched := v_res_sched ||     
        ('UPDATE dg_full.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.wf_time_sched || ''',' || 
            'period_refresh_comment = ''' || rec.wf_event_sched_str || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.wf_name  || '''' || 
          ' AND schema_src_id = ''' || rec.category || '''' ||
          ' AND src_cd = ''CTL''; ')::TEXT || chr(10);
    END IF;
    RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
  END LOOP;
  
  -- Расписание дублируем у таблиц по CTL объектам - SRC
  FOR rec IN ( SELECT DISTINCT  
                        jd.src_table,
                        jd.src_schema,
                        jd.espd_wf_time_sched,
                        jd.tgt_table,
                        jd.tgt_schema,
                        jd.wf_time_sched
               FROM temp_json_det jd 
               WHERE 1 = 1
                 AND jd.src_table <> '~'
                 AND jd.src_schema <> '~'
                 AND jd.tgt_table <> '~'
                 AND jd.tgt_schema <> '~'
                 AND jd.espd_wf_time_sched <> '~'
                 AND jd.wf_time_sched <> '~'
              ) LOOP 
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_scheduler_hsat sch 
        WHERE 1=1
          AND sch.node_src_id = rec.src_table
          AND sch.schema_src_id = rec.src_schema
          AND sch.src_cd = 'GP';
      
        IF rec.espd_wf_time_sched IS NOT NULL AND dg_full.meta_is_wellformed(rec.espd_wf_time_sched) = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.src_table || ''',''' || rec.espd_wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
    
        IF COALESCE(v_cnt,0) = 0 THEN  
        v_scheduler_id := nextval('dg_full.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO dg_full.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('              || 
        v_scheduler_id         || ', current_timestamp, ''GP''::varchar(20),' ||
        p_wf_load_id           || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.src_table          || ''',''' ||
        rec.src_schema         || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.espd_wf_time_sched || ''',NULL::TEXT,''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        v_res_sched := v_res_sched ||     
        ('UPDATE dg_full.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.espd_wf_time_sched || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.src_table  || '''' || 
          ' AND schema_src_id = ''' || rec.src_schema || '''' ||
          ' AND src_cd = ''GP''; ')::TEXT || chr(10);
    END IF;
    RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
         
        -- Расписание дублируем у таблиц по CTL объектам - TGT
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_scheduler_hsat sch 
        WHERE 1=1
          AND sch.node_src_id = rec.tgt_table
          AND sch.schema_src_id = rec.tgt_schema
          AND sch.src_cd = 'GP';
      
        IF rec.wf_time_sched IS NOT NULL AND dg_full.meta_is_wellformed(rec.wf_time_sched) = FALSE THEN
           v_res_sched := v_res_sched || '--''' || rec.tgt_table || ''',''' || rec.wf_time_sched || ''' : формат CRON не валидный' || chr(10); -- если формат CRON не валидный, начинаем новую итерацию цикла    
        END IF;
        RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
    
        IF COALESCE(v_cnt,0) = 0 THEN  
        v_scheduler_id := nextval('dg_full.synth_key_seq');
    
        v_res_sched := v_res_sched ||     
        ('INSERT INTO dg_full.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, 
        node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES ('              || 
        v_scheduler_id         || ', current_timestamp, ''GP''::varchar(20),' ||
        p_wf_load_id           || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.tgt_table          || ''',''' ||
        rec.tgt_schema         || ''', ''Auto''::varchar(250), 1, 1, ''' ||
        rec.wf_time_sched      || ''',''' ||
        '{''''wf_event_sched'''': [] }' || ''',''TRUE''::bool); ')::TEXT || chr(10);
        ELSE
        v_res_sched := v_res_sched ||     
        ('UPDATE dg_full.meta_scheduler_hsat
        SET
             period_type_comment = '''    || rec.wf_time_sched || ''', load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = '''   || rec.tgt_table  || '''' || 
          ' AND schema_src_id = ''' || rec.tgt_schema || '''' ||
          ' AND src_cd = ''GP''; ')::TEXT || chr(10);
    END IF;
    RAISE NOTICE 'v_res_sched - %', v_res_sched::TEXT;
  END LOOP;

  -- Связи между объектами espd_wf -> src_table -> ctl_wf ->  tgt_table
  FOR rec IN ( SELECT *   FROM temp_json_det jd) LOOP
     IF rec.fl_ins = 1 THEN 
        -- espd_wf_name as src_node
        -- espd_category as src_schema
        -- src_table as tgt_node
        -- src_schema as tgt_schema
        -- Проверяем наличие и Заполняем meta_edge_link
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_edge_link e
        WHERE 1=1
          AND e.src_node_src_id = rec.espd_wf_name
          AND e.src_schema_src_id = rec.espd_category
          AND e.target_node_src_id = rec.src_table
          AND e.target_schema_src_id = rec.src_schema;
      
        IF rec.espd_wf_name IS NULL THEN
           v_res_edge := v_res_edge || '''' || rec.espd_wf_name || ''':не найден объект espd' || chr(10); --     
        END IF;

       IF rec.espd_wf_name IS NOT NULL AND COALESCE(v_cnt,0) = 0 THEN
          v_edge_id := nextval('dg_full.synth_key_seq');

          v_res_edge := v_res_edge || 
          ('INSERT INTO dg_full.meta_edge_link (edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,
                        src_node_src_id,src_schema_src_id,
                        target_node_src_id,target_schema_src_id,
                        edge_type_src_id,property_id,weight,order_by,is_active)
            VALUES ( '    ||
               v_edge_id || ', current_timestamp, ''GP'', -1, ''1900-01-01''::date, ''2999-12-31''::date,current_timestamp, ''' ||
               rec.espd_wf_name  || ''',''' ||
               rec.espd_category || ''',''' ||
               rec.src_table     || ''',''' ||
               rec.src_schema    || ''',' ||
               '1 ,-1 ,1 ,1 ,TRUE::bool);')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_edge - %', v_res_edge::TEXT;
   END IF;
   -- связи только для src->CTL->tgt
   IF rec.fl_ins IN (0,1,2) THEN 
   -- src_tabe as src_node
   -- src_schema as src_schema
   -- wf_name as tgt_node
   -- category as tgt_schema
        -- Проверяем наличие и Заполняем meta_edge_link
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_edge_link e
        WHERE 1=1
          AND e.src_node_src_id = rec.src_table
          AND e.src_schema_src_id = rec.src_schema
          AND e.target_node_src_id = rec.wf_name
          AND e.target_schema_src_id = rec.category;
      
       IF COALESCE(v_cnt,0) = 0 THEN
          v_edge_id := nextval('dg_full.synth_key_seq');

          v_res_edge := v_res_edge || 
          ('INSERT INTO dg_full.meta_edge_link (edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,
                        src_node_src_id,src_schema_src_id,
                        target_node_src_id,target_schema_src_id,
                        edge_type_src_id,property_id,weight,order_by,is_active)
            VALUES ( '    ||
               v_edge_id || ', current_timestamp, ''GP'', -1, ''1900-01-01''::date, ''2999-12-31''::date,current_timestamp, ''' ||
               rec.src_table  || ''',''' ||
               rec.src_schema || ''',''' ||
               rec.wf_name    || ''',''' ||
               rec.category   || ''',' ||
               '1 ,-1 ,1 ,1 ,TRUE::bool);')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_edge - %', v_res_edge::TEXT;
   
        -- wf_name as src_node
        -- category as src_schema
        -- tgt_table as tgt_node
        -- tgt_schema as tgt_schema
        -- Проверяем наличие и Заполняем meta_edge_link
        SELECT count(*) INTO v_cnt
        FROM dg_full.meta_edge_link e
        WHERE 1=1
          AND e.src_node_src_id = rec.wf_name
          AND e.src_schema_src_id = rec.category
          AND e.target_node_src_id = rec.tgt_table
          AND e.target_schema_src_id = rec.tgt_schema;
      
       IF COALESCE(v_cnt,0) = 0 THEN
          v_edge_id := nextval('dg_full.synth_key_seq');

          v_res_edge := v_res_edge || 
          ('INSERT INTO dg_full.meta_edge_link (edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,
                        src_node_src_id,src_schema_src_id,
                        target_node_src_id,target_schema_src_id,
                        edge_type_src_id,property_id,weight,order_by,is_active)
            VALUES ( '    ||
               v_edge_id || ', current_timestamp, ''GP'', -1, ''1900-01-01''::date, ''2999-12-31''::date,current_timestamp, ''' ||
               rec.wf_name || ''',''' ||
               rec.category || ''',''' ||
               rec.tgt_table || ''',''' ||
               rec.tgt_schema  || ''',' ||
               '1 ,-1 ,1 ,1 ,TRUE::bool);')::TEXT || chr(10);
        END IF;
        RAISE NOTICE 'v_res_edge - %', v_res_edge::TEXT;
    END IF;
    -- список не найденных объектов
    IF rec.fl_ins = 0 THEN 
        v_res_edge := v_res_edge || '--''' || rec.wf_name || ''',''' || rec.wf_event_sched || ''' : не найдена ссылка на espd объект' || chr(10); --  не найдена ссылка на espd объект    
    END IF;

   END LOOP;
----------------------------------------------------------------------------------------------------
  
    DROP TABLE temp_json;
    DROP TABLE temp_espd;
    DROP TABLE temp_ctl;
    DROP TABLE temp_json_det;

    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_parse_json'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN COALESCE(v_res_node,'~') || chr(10) ||
           COALESCE(v_res_sched,'~')  || chr(10) ||
           COALESCE(v_res_edge,'~');

    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_parse_json'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;




$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_scheduler_hsat(p_tbl_src_id text, p_sch_src_id text, p_period_type_id int4, p_node_type_src_id int4, p_period_type_comment text, p_period_refresh_comment text, p_is_wf_time_sched_active bool, p_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
    
    
    
    
    
    
/* Change Log 
 *   
 * */   
      
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    v_scheduler_id   bpchar(10);
    v_cnt            int4;
    v_cnt_sch        int4;
    v_cnt_tbl        int4;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_sch_src_id = %I , p_tbl_src_id = %I '
        , p_sch_src_id
        , p_tbl_src_id
    );
    -- Наличие схемы в списке схем ПКАП-а
    SELECT count(*) INTO v_cnt_sch
    FROM dg_full.meta_schema_ref_table t
    WHERE 1=1
      AND t.schema_src_id = p_sch_src_id
      ;

    IF coalesce(v_cnt_sch,0) = 0 THEN
        RETURN -2;    
    END IF;
    -- Наличие таблицы в списке таблиц
    SELECT count(*) INTO v_cnt_tbl
    FROM pg_class pgc 
    JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
    JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
    WHERE 1 = 1 
      AND pgc.relname !~~ '%_prt_%'::text 
      AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
      AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
      AND pgn.nspname::text = p_sch_src_id
      AND pgc.relname::text = p_tbl_src_id
    ;

    IF COALESCE(v_cnt_tbl,0) = 0 THEN
        RETURN -3;    
    END IF;
    -- Наличие строки с расписанием 
    SELECT count(*) INTO v_cnt
    FROM dg_full.meta_scheduler_hsat t
    WHERE 1=1
      AND t.node_src_id = p_tbl_src_id
      AND t.schema_src_id = p_sch_src_id;

    IF dg_full.meta_is_wellformed(p_period_type_comment) = FALSE THEN
        RETURN -1;    
    END IF;
        
    IF COALESCE(v_cnt,0) = 0 THEN
        v_scheduler_id := nextval('dg_full.synth_key_seq');
    
        INSERT INTO dg_full.meta_scheduler_hsat (
        scheduler_id,
        load_dttm,
        src_cd,
        wf_load_id,
        eff_from_dttm,
        eff_to_dttm,
        last_seen_dttm,
        node_src_id,
        schema_src_id,
        scheduler_type_src_id,
        dt_from,
        dt_to,
        time_from,
        time_to,
        period_type_id,
        every_times,
        source_object,
        run_function_src_id,
        node_type_src_id,
        period_type_comment,
        period_refresh_comment,
        user_refresh,
        ods_ready,
        dm_ready,
        ods_ready_dt,
        dm_ready_dt,
        ods_ready_tm,
        dm_ready_tm,
        ods_start,
        ods_start_tm,
        is_wf_time_sched_active
               )
        VALUES (
        v_scheduler_id,
        current_timestamp,
        'GP'::varchar(20),
        p_wf_load_id,
        '1900-01-01'::timestamp,
        '2999-12-31'::timestamp,
        current_timestamp,
        p_tbl_src_id,
        p_sch_src_id,
        'Auto'::varchar(250),
        NULL::int4,
        NULL::int4,
        NULL::int4,
        NULL::int4,
        p_period_type_id,
        NULL::int4,
        NULL::text, -- source_object,
        NULL::text, -- run_function_src_id,
        p_node_type_src_id,
        p_period_type_comment,
        p_period_refresh_comment,
        NULL::text, -- user_refresh,
        NULL::text, -- ods_ready,
        NULL::text, -- dm_ready,
        NULL::date, -- ods_ready_dt,
        NULL::date, -- dm_ready_dt,
        NULL::time, -- ods_ready_tm,
        NULL::time, -- dm_ready_tm,
        NULL::text, -- ods_start,
        NULL::time, -- ods_start_tm,
        p_is_wf_time_sched_active
           );
    ELSE 
        SELECT scheduler_id INTO v_scheduler_id
        FROM dg_full.meta_scheduler_hsat
        WHERE 1=1
          AND node_src_id = p_tbl_src_id
          AND schema_src_id = p_sch_src_id;
        
        UPDATE dg_full.meta_scheduler_hsat
        SET
            period_type_id = p_period_type_id, 
            node_type_src_id = p_node_type_src_id,
            period_type_comment = p_period_type_comment, 
            period_refresh_comment = p_period_refresh_comment,
            is_wf_time_sched_active = p_is_wf_time_sched_active,
            load_dttm = current_timestamp,
            last_seen_dttm = current_timestamp 
        WHERE 1=1
          AND node_src_id = p_tbl_src_id
          AND schema_src_id = p_sch_src_id;
    END IF;
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_scheduler_hsat'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN v_scheduler_id::int4
    ;
    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_scheduler_hsat'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;








$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.fill_meta_scheduler_hsat_json(p_json json, p_wf_load_id int8)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
/* Change Log 
 * FVV Формат json
 *     p_tbl_src_id text, 
       p_sch_src_id text, 
       p_period_type_nm text, 
       p_node_type_src_nm text, 
       p_period_type_comment text, 
       p_period_refresh_comment text, 
       p_is_wf_time_sched_active bool
 * */   
      
DECLARE
    v_params         TEXT DEFAULT '';
    v_res_statements TEXT DEFAULT '';
    v_scheduler_id   bpchar(10);
    v_cnt            int4;
    v_cnt_sch        int4;
    v_cnt_tbl        int4;
    rec              record;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I '
        , p_wf_load_id
    );

    RAISE NOTICE 'input, %', p_json;

    CREATE TEMPORARY TABLE temp_json AS
    SELECT *
    FROM json_populate_recordset(NULL::record, p_json) 
    AS (
       p_tbl_src_id text, 
       p_sch_src_id text, 
       p_period_type_nm text, 
       p_node_type_src_nm text, 
       p_period_type_comment text, 
       p_period_refresh_comment text, 
       p_is_wf_time_sched_active bool
    );  
    
    -- Наличие схемы и таблицы в списке
    CREATE TEMPORARY TABLE temp_table AS  
    SELECT j.p_tbl_src_id AS node_src_id, 
           j.p_sch_src_id AS schema_src_id,  
           p.period_type_id AS period_type_id, 
           n.node_type_src_id AS node_type_src_id, 
           j.p_period_type_comment AS period_type_comment, 
           j.p_period_refresh_comment AS period_refresh_comment, 
           j.p_is_wf_time_sched_active AS is_wf_time_sched_active,
           sch.scheduler_id
    FROM pg_class pgc 
    JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
    JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
    JOIN temp_json j ON pgn.nspname = j.p_sch_src_id AND pgc.relname = j.p_tbl_src_id
    LEFT JOIN dg_full.meta_period_type_ref_table p ON p.descr = j.p_period_type_nm
    LEFT JOIN dg_full.meta_node_type_ref_table n ON n.descr = j.p_node_type_src_nm
    LEFT JOIN dg_full.meta_scheduler_hsat sch ON sch.node_src_id = j.p_tbl_src_id AND sch.schema_src_id = j.p_sch_src_id 
    WHERE 1 = 1 
      AND pgc.relname !~~ '%_prt_%'::text 
      AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) 
      AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
    ;
    v_res_statements := '';
    FOR rec IN ( SELECT * FROM temp_table) 
    LOOP 
    
    IF dg_full.meta_is_wellformed(rec.period_type_comment) = FALSE THEN
        CONTINUE; -- если формат CRON не валидный, начинаем новую итерацию цикла    
    END IF;
        
    IF rec.scheduler_id IS NULL THEN  
        v_scheduler_id := nextval('dg_full.synth_key_seq');
    
        v_res_statements := v_res_statements ||     
        ('INSERT INTO dg_full.meta_scheduler_hsat (
        scheduler_id, load_dttm, src_cd, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm, node_src_id, schema_src_id, scheduler_type_src_id, period_type_id,
        node_type_src_id, period_type_comment, period_refresh_comment, is_wf_time_sched_active)
        VALUES (' || 
        v_scheduler_id || ', current_timestamp, ''GP''::varchar(20),' ||
        p_wf_load_id  || ', ''1900-01-01''::timestamp, ''2999-12-31''::timestamp, current_timestamp,''' ||
        rec.node_src_id || ''',''' ||
        rec.schema_src_id || ''', ''Auto''::varchar(250), ' ||
        rec.period_type_id || ',' ||
        rec.node_type_src_id || ',''' ||
        rec.period_type_comment || ''',''' ||
        rec.period_refresh_comment || ''',''' ||
        rec.is_wf_time_sched_active || '''::bool); ')::TEXT || chr(10);
    ELSE
        v_res_statements := v_res_statements ||     
        ('UPDATE dg_full.meta_scheduler_hsat
        SET
            period_type_id = ' || rec.period_type_id || ',' || 
            'node_type_src_id = ' || rec.node_type_src_id || ',' ||
            'period_type_comment = ''' || rec.period_type_comment || ''',' || 
            'period_refresh_comment = ''' || rec.period_refresh_comment || ''',' ||
            'is_wf_time_sched_active = ''' || rec.is_wf_time_sched_active || '''::bool, load_dttm = current_timestamp, last_seen_dttm = current_timestamp 
        WHERE 1=1
            AND node_src_id = ''' || rec.node_src_id || '''' || 
          ' AND schema_src_id = ''' || rec.schema_src_id || '''; ')::TEXT || chr(10);
    END IF;

    END LOOP;

    DROP TABLE temp_json;
    DROP TABLE temp_table;

    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                  v_res_statements
                , v_params
                , 'fill_meta_scheduler_hsat_json'
                , p_wf_load_id
                , p_wf_load_id
                , 0::int4 
            )
            ;
    RETURN v_res_statements;

    EXCEPTION
        WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'fill_meta_scheduler_hsat_json'
                , p_wf_load_id
                , p_wf_load_id
                , 3::int4 
            )
            ;
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;









$$
EXECUTE ON ANY;


----------------------

CREATE OR REPLACE FUNCTION dg_full.meta_apply_all_replacements(template_text text, replacement_json jsonb, json_table jsonb)
	RETURNS text
	LANGUAGE plpgsql
	IMMUTABLE
AS $$
	
	
    
    
DECLARE
    key_value RECORD;
    result_text TEXT := template_text;
   json_table jsonb := json_table; 
BEGIN
    FOR key_value IN 
        SELECT * FROM jsonb_each_text(replacement_json)
    LOOP
            result_text:= REPLACE(result_text,'{{table_html}}',dg_full.meta_json_to_html_table(json_table) );
        result_text := REPLACE(
            result_text, 
            '{{' || key_value.key || '}}', 
            COALESCE(key_value.value, '')
        );
    END LOOP;
    RETURN result_text;
END;




$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_apply_all_replacements_v01(template_text text, replacement_json jsonb)
	RETURNS text
	LANGUAGE plpgsql
	IMMUTABLE
AS $$
	
DECLARE
    key_value RECORD;
    result_text TEXT := template_text;
BEGIN
    FOR key_value IN 
        SELECT * FROM jsonb_each_text(replacement_json)
    LOOP
        result_text := REPLACE(
            result_text, 
            '{{' || key_value.key || '}}', 
            COALESCE(key_value.value, '')
        );
    END LOOP;
    RETURN result_text;
END;

$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_clean_html_cell_content(html_content text)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
DECLARE
    result_text text;
BEGIN
    result_text := html_content;
    
    -- 1. Сначала заменяем заэкранированные HTML-теги (если они есть)
    result_text := replace(result_text, 'lt;br/gt;', chr(10));
    result_text := replace(result_text, 'lt;brgt;', chr(10));
    result_text := replace(result_text, 'lt;br /gt;', chr(10));
    
    -- 2. Заменяем обычные теги переноса строки
    result_text := regexp_replace(result_text, '<br\s*/?>', chr(10), 'gi');
    
    -- 3. Удаляем все остальные HTML-теги
    result_text := regexp_replace(result_text, '<[^>]*>', '', 'g');
    
    -- 4. Заменяем HTML-сущности на соответствующие символы
    -- Важно: сначала заменяем &amp;, чтобы не создавать рекурсию
    result_text := replace(result_text, '&amp;', '&');
    
    -- Затем заменяем другие сущности
    result_text := replace(result_text, 'gt;', '>');    -- >
    result_text := replace(result_text, 'lt;', '<');    -- <
    result_text := replace(result_text, 'nbsp;', ' ');  -- неразрывный пробел
    result_text := replace(result_text, 'quot;', '"');  -- двойные кавычки
    result_text := replace(result_text, '#39;', '''');  -- одинарные кавычки
    result_text := replace(result_text, 'apos;', ''''); -- одинарные кавычки (альтернатива)
    
    -- 5. Заменяем числовые HTML-сущности
    result_text := replace(result_text, '#62;', '>');
    result_text := replace(result_text, '#60;', '<');
    result_text := replace(result_text, '#34;', '"');
    result_text := replace(result_text, '#160;', ' ');
    result_text := replace(result_text, '#32;', ' ');
    
    -- 6. Заменяем &amp; снова, если появились новые после замен
    result_text := replace(result_text, '&amp;', '&');
    
    -- 7. Обрабатываем специальные символы SQL
    result_text := replace(result_text, 'lt;gt;', '<>'); -- для оператора "не равно"
   result_text := replace(result_text, 'lt;=', '<=');   -- для оператора "меньше или равно"
    result_text := replace(result_text, 'gt;=', '>=');   -- для оператора "больше или равно"
    
    -- 8. Убираем лишние пробелы (но сохраняем переносы строк)
   -- Заменяем множественные пробелы/табы на один пробел
    result_text := regexp_replace(result_text, '[ \t\r\f\v]+', ' ', 'g');
    
    -- 9. Убираем пробелы в начале и конце каждой строки (но сохраняем пустые строки)
    result_text := regexp_replace(result_text, '^[ \t]+|[ \t]+$', '', 'gm');
    
    -- 10. Убираем пробелы в начале и конце всего текста
    result_text := trim(result_text);
    
    -- 11. Если есть множественные переносы строк, оставляем максимум 2 подряд
    result_text := regexp_replace(result_text, '\n{3,}', chr(10) || chr(10), 'g');
    
    RETURN result_text;
END;

$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_comment_creation(wf_id text)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	

DECLARE
    rec        record;
   	v_res_tb   TEXT;
   rec_att        record;
   	v_res_att   TEXT;
BEGIN
	
	
CREATE TEMPORARY TABLE comm_tb  AS
	 WITH eff_date AS (SELECT max(att.eff_date_ts) AS eff_date_ts,       
            tb.pm_name AS tb_pm_name
           FROM s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_attribute att
             JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table tb ON att.stock_element_id_ent = tb.stock_element_id_ent
          WHERE 1 = 1 --AND tb.pm_name =upper('z_property_grp') 
          GROUP BY            tb.pm_name)
         , smd AS (      
         SELECT max(att.eff_date_ts) AS eff_date_ts,
            att.is_active_flg,
            att.model_element_type_name,
            att.name,
            att.pm_data_type,
            att.pm_name,
            tb.name AS tb_name,
            tb.pm_name AS tb_pm_name
           FROM s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_attribute att
             JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table tb ON att.stock_element_id_ent = tb.stock_element_id_ent
          WHERE 1 = 1  AND (att.eff_date_ts ,tb.pm_name) IN (SELECT eff_date_ts ,tb_pm_name FROM  eff_date)
          GROUP BY  att.is_active_flg, att.model_element_type_name, 
          att.name,
          att.pm_data_type, 
          att.pm_name,
          tb.name,
          tb.pm_name
          )      
SELECT s2t."T-schema",
    s2t."T-schema-note",
    s2t."T-name",
    s2t."T-note",
    REPLACE(REPLACE(REPLACE (smd.tb_name, '"',''),'\',''),'''','') AS tb_comment,
    s2t."T-col-name",
    s2t."T-col-type",
    s2t."T-col-note",
    smd.name AS attr_comment
   FROM dg_full.vmeta_s2t_meta_target_columns s2t
     LEFT JOIN dg_full.meta_schema_ref_table msrt ON s2t."T-schema" = msrt.schema_src_id::text
     LEFT JOIN smd ON smd.tb_pm_name = upper(s2t."T-name") AND upper(s2t."T-col-name") = smd.pm_name
          --WHERE s2t."T-name"='z_property_grp' 
    GROUP BY s2t."T-schema",
    s2t."T-schema-note",
    s2t."T-name",
    s2t."T-note",
    smd.tb_name ,
    s2t."T-col-name",
    s2t."T-col-type",
    s2t."T-col-note",
    smd.name  
   DISTRIBUTED BY ("T-schema");
   RAISE NOTICE 'temp_schema'
  ;

  
  
   -- meta_object_group_ref_table
  v_res_tb := '';
  FOR rec IN (SELECT DISTINCT 
                     o."T-schema",
                     o."T-name",
                     o.tb_comment                  
              FROM comm_tb o
              WHERE tb_comment IS NOT NULL AND "T-note" IS NULL 
              ) 
  LOOP
        RAISE NOTICE 'tb_comment_start';
    -- Проверяем наличие и Заполняем meta_object_group_ref_table
         
         RAISE NOTICE 'COMMENT ON TABLE %.% is  % ;',rec."T-schema", rec."T-name",rec.tb_comment;
          v_res_tb := v_res_tb || 
          ('COMMENT ON TABLE ' ||
         rec."T-schema"||'.'||
         rec."T-name"||' IS '''||
         rec.tb_comment||'''; '
          )::TEXT|| chr(10);
            RAISE NOTICE 'v_res_obj ';    
  
       END LOOP;
   
     v_res_att := '';
  FOR rec_att IN (SELECT DISTINCT 
                     o."T-schema",
                     o."T-name",
                     o."T-col-name",
                     o."T-col-note",
                     o.attr_comment                  
              FROM comm_tb o
              WHERE attr_comment IS NOT NULL AND "T-col-note" IS NULL 
              ) 
  LOOP
        RAISE NOTICE 'tb_comment_start';
    -- Проверяем наличие и Заполняем meta_object_group_ref_table
         
         RAISE NOTICE 'COMMENT ON COLUMN %.% is  % ;',rec_att."T-schema", rec_att."T-name",rec_att.attr_comment;
          v_res_att := v_res_att || 
          ('COMMENT ON COLUMN ' ||
         rec_att."T-schema"||'.'||
         rec_att."T-name"||'.'||
         rec_att."T-col-name"||
         ' IS '''||
         rec_att.attr_comment||'''; '
          )::TEXT|| chr(10);
            RAISE NOTICE 'v_res_obj ';    
  
       END LOOP;  
      
      
      
   RAISE NOTICE 'tb_comment_end';
   
DROP TABLE comm_tb;

    
    -- Выполняем запрос и возвращаем результат
    RETURN  v_res_tb || chr(100)|| v_res_att ;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '(%:%)',  SQLSTATE, SQLERRM;
END;




$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_expand_field(p_field text, p_min int4, p_max int4)
	RETURNS _int4
	LANGUAGE plpgsql
	IMMUTABLE
AS $$
	
    
    
    
DECLARE
    v_part   TEXT;
    v_groups TEXT[];
    v_m      int;
    v_n      int;
    v_k      int;
    v_ret    int[];
    v_tmp    int[];
BEGIN

    -- step 1: basic parameter check

    IF COALESCE(p_field, '') = '' THEN
        RAISE EXCEPTION 'invalid parameter "p_field"';
    END IF;

    IF p_min IS NULL OR p_max IS NULL OR p_min < 0 OR p_max < 0 OR p_min > p_max THEN
        RAISE EXCEPTION 'invalid parameter(s) "p_min" or "p_max"';
    END IF;

    -- step 2: handle special cases * and */k

    IF p_field = '*' THEN
        SELECT array_agg(v_x::int) INTO v_ret FROM generate_series(p_min, p_max) as v_x;
        RETURN v_ret;
    END IF;

    IF p_field ~ '^\*/\d+$' THEN
        v_groups = regexp_matches(p_field, '^\*/(\d+)$');
        v_k := v_groups[1];
        IF v_k < 1 OR v_k > p_max THEN
            RAISE EXCEPTION 'invalid range step: expected a step between 1 and %, got %', p_max, v_k;
        END IF;
        SELECT array_agg(v_x::int) INTO v_ret FROM generate_series(p_min, p_max, v_k) AS v_x;
        RETURN v_ret;
    END IF;

    -- step 3: handle generic expression with values, lists or ranges

    v_ret := '{}'::int[];
    FOR v_part IN SELECT * FROM regexp_split_to_table(p_field, ',')
        LOOP
            IF v_part ~ '^\d+$' THEN
                v_n := v_part;
                IF v_n < p_min OR v_n > p_max THEN
                    RAISE EXCEPTION 'value out of range: expected values between % and %, got %', p_min, p_max, v_n;
                END IF;
                v_ret = v_ret || v_n;
            ELSEIF v_part ~ '^\d+-\d+$' THEN
                v_groups = regexp_matches(v_part, '^(\d+)-(\d+)$');
                v_m := v_groups[1];
                v_n := v_groups[2];
                IF v_m > v_n THEN
                    RAISE EXCEPTION 'inverted range bounds';
                END IF;
                IF v_m < p_min OR v_m > p_max OR v_n < p_min OR v_n > p_max THEN
                    RAISE EXCEPTION 'invalid range bound(s): expected bounds between % and %, got % and %', p_min, p_max, v_m, v_n;
                END IF;
                SELECT array_agg(v_x) INTO v_tmp FROM generate_series(v_m, v_n) as v_x;
                v_ret := v_ret || v_tmp;
            ELSEIF v_part ~ '^\d+-\d+/\d+$' THEN
                v_groups = regexp_matches(v_part, '^(\d+)-(\d+)/(\d+)$');
                v_m := v_groups[1];
                v_n := v_groups[2];
                v_k := v_groups[3];
                IF v_m > v_n THEN
                    RAISE EXCEPTION 'inverted range bounds';
                END IF;
                IF v_m < p_min OR v_m > p_max OR v_n < p_min OR v_n > p_max THEN
                    RAISE EXCEPTION 'invalid range bound(s): expected bounds between % and %, got % and %', p_min, p_max, v_m, v_n;
                END IF;
                IF v_k < 1 OR v_k > p_max THEN
                    RAISE EXCEPTION 'invalid range step: expected a step between 1 and %, got %', p_max, v_k;
                END IF;
                SELECT array_agg(v_x) INTO v_tmp FROM generate_series(v_m, v_n, v_k) as v_x;
                v_ret := v_ret || v_tmp;
            ELSE
                RAISE EXCEPTION 'invalid expression';
            END IF;
        END LOOP;

    SELECT array_agg(v_x)
    INTO v_ret
    FROM (
             SELECT DISTINCT unnest(v_ret) as v_x
             ORDER BY v_x
         ) AS sub;
    RETURN v_ret;
END;




$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_is_wellformed(p_exp text)
	RETURNS bool
	LANGUAGE plpgsql
	IMMUTABLE
AS $$
	
    
    
DECLARE
    v_dummy boolean;
BEGIN
   
    BEGIN 
        v_dummy := dg_full.meta_match(now(), p_exp);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;
    RETURN TRUE;
END



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_json_to_html_table(json_data jsonb)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
 

DECLARE
html_output TEXT := '<table border="1">';
key TEXT;
row jsonb;
value TEXT;
BEGIN
-- Извлекаем ключи из первого объекта JSON для заголовков таблицы

	
-- Создаем заголовок таблицы
html_output := html_output || '<tr>';
FOR key IN SELECT jsonb_object_keys(json_data->0)
LOOP
html_output := html_output || '<th>' || key || '</th>';
END LOOP;
html_output := html_output || '</tr>';

-- Проходим по всем строкам JSON и добавляем их в таблицу
FOR row IN SELECT * FROM jsonb_array_elements(json_data)
LOOP
html_output := html_output || '<tr>';
FOR key IN SELECT jsonb_object_keys(row)
LOOP
value:=row->>key;
html_output := html_output || '<td>' || COALESCE (value,'') || '</td>';
END LOOP;
html_output := html_output || '</tr>';
END LOOP;

html_output := html_output || '</table>';

RETURN html_output;

END
;

$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_match(p_ts timestamptz, p_exp text)
	RETURNS bool
	LANGUAGE plpgsql
	IMMUTABLE
AS $$
	
    
    
DECLARE
    v_field_min int[] := '{ 0,  0,  1,  1, 0}';
    v_field_max int[] := '{59, 23, 31, 12, 7}';
    v_groups    text[];
    v_fields    int[];
    v_ts_parts  int[];

BEGIN

    IF p_ts IS NULL THEN
        RAISE EXCEPTION 'invalid parameter "p_ts": must not be null';
    END IF;

    IF p_exp IS NULL THEN
        RAISE EXCEPTION 'invalid parameter "p_exp": must not be null';
    END IF;

    v_groups = regexp_split_to_array(trim(p_exp), '\s+');
    IF array_length(v_groups, 1) != 5 THEN
        RAISE EXCEPTION 'invalid parameter "p_exp": five space-separated fields expected';
    END IF;

    v_ts_parts[1] := date_part('minute', p_ts);
    v_ts_parts[2] := date_part('hour', p_ts);
    v_ts_parts[3] := date_part('day', p_ts);
    v_ts_parts[4] := date_part('month', p_ts);
    v_ts_parts[5] := date_part('dow', p_ts); -- Sunday = 0

    FOR n IN 1..5
        LOOP
            v_fields := dg_full.meta_expand_field(v_groups[n], v_field_min[n], v_field_max[n]);
            -- hack FOR DOW: fields might contain 0 or 7 FOR Sunday; IF there's a 7, make sure there's a 0 too
            IF n = 5 AND ARRAY [7] <@ v_fields THEN
                v_fields := ARRAY [0] || v_fields;
            END IF;
            IF NOT ARRAY [v_ts_parts[n]] <@ v_fields THEN
                RETURN FALSE;
            END IF;
        END LOOP;

    RETURN TRUE;
END



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_sys_data_object_detail_load(p_wf_run_id int8)
	RETURNS void
	LANGUAGE plpgsql
	VOLATILE
AS $$
	

declare
   v_insert_sql   text;

begin

   CREATE TEMP TABLE tmp (
      object_id int8,
      total_object_size numeric,
      object_size numeric,
      indexes_size numeric
   )
   DISTRIBUTED by (object_id);

   INSERT INTO tmp
   select * from dg_full.meta_sys_objects_size_load();


   v_insert_sql := format('INSERT INTO dg_full.meta_sys_data_object_detail'
               '(object_id, total_object_size, object_size, indexes_size, inserted_dttm,  wf_load_id)' || chr(10) ||
                       'SELECT object_id,'|| chr(10) ||
                            'total_object_size,'|| chr(10) ||
                            'object_size,'|| chr(10) ||
                            'indexes_size,'|| chr(10) ||
                            'now(),'|| chr(10) ||
                            '%1$s'|| chr(10) ||
                            'FROM tmp', p_wf_run_id);



   raise notice '%', v_insert_sql;
   EXECUTE v_insert_sql;


   DROP TABLE if exists tmp;



END;



$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.meta_sys_objects_size_load(object_id int8, total_object_size numeric, object_size numeric, indexes_size numeric)
	RETURNS TABLE (object_id int8, total_object_size numeric, object_size numeric, indexes_size numeric)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	

begin

    RETURN QUERY
        SELECT c.oid::int8,
             (gpti.sotaidtablesize + gpti.sotaididxsize)::numeric,
             gpti.sotaidtablesize::numeric,
             gpti.sotaididxsize::numeric
        FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace AND c.relkind = 'r' AND ns.nspname LIKE 's_grnplm_as_cib_gm%'
                  LEFT JOIN s_grnplm_ld_cib_gm_dsc_dcp_dm.gp_size_of_table_and_indexes_disk gpti ON c.oid = gpti.sotaidoid;


end


$$
;


--------------------------------

CREATE OR REPLACE FUNCTION dg_full.return_meta_edge_link(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	

/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-01-13 Add chain entity -> wf -> entity
 * 2025-04-11 Add QS edge links
 * 2025-11-07 Add SMD
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_edge_link';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_edge_link';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);


-- dg_full.vmeta_sg_category source
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_sg_category - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_sg_category AS 
WITH RECURSIVE sg_category(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parentid   AS parent_id,
            g.name::TEXT AS name_,
            1 AS depth,
            ARRAY[g.name::TEXT] AS path,
            false AS cycle,
            g.name AS root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g -- s_grnplm_as_cib_gm_stg_espd.ctl_category g
          WHERE 1 = 1 
            AND g.parentid = 0 
            AND g.id in (1764 ,1964)
            AND g.deleted = false
        UNION ALL
         SELECT g1.id,
            g1.parentid AS parent_id,
            g1.name::TEXT AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name::TEXT,
            g1.name::TEXT = ANY (p.path),
            p.root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g1 -- s_grnplm_as_cib_gm_stg_espd.ctl_category g1
             JOIN sg_category p ON p.id = g1.parentid
          WHERE 1 = 1 AND NOT p.cycle
        )
 SELECT sg_category.id,
    sg_category.parent_id,
    sg_category.name_,
    sg_category.depth,
    sg_category.path,
    sg_category.cycle,
    sg_category.root_name_id
   FROM sg_category
DISTRIBUTED BY (id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_sg_category;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_sg_category - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_smd0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_smd0 AS 
SELECT -- свзязи  дата продуктов СМД и  ESPD подписки
 'SMD'::text AS src_cd,
lower(pr.meta_product_name)  AS src_node_src_id,
lower(pr.pm_name) AS src_schema_src_id,
s.core_uuid AS target_node_src_id,
n.schema_src_id AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
lower(pr.pm_name)|| '||' || lower(pr.meta_product_name) AS src_node_id,
n.schema_src_id || '||' || s.core_uuid AS target_node_id,
'Flow' AS tgt_node_type_cd,
'SMD'::text AS src_node_type_cd,
'1'::TEXT AS enable_dq 
 FROM s_grnplm_as_cib_gm_stg_espd.v_smd_subscription_report s -- подписки
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_subscr_dp_rel r ON  s.subscription_uuid = r.subscription_uuid
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr  ON pr.stock_element_id = r.stock_element_id_sch
JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND s.subscription_uuid = n.node_src_id -- наши подписки из CTL
WHERE 1=1
--AND (pr.data_product_uuid, pr.eff_date_ts) in (SELECT pr1.data_product_uuid, max(pr1.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr1 group by 1)
AND s.subscription_status_display_name = 'Активна'
DISTRIBUTED BY (target_schema_src_id,target_node_src_id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_smd0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_smd0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;



v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_smd - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_smd AS 
SELECT --связь между таблицой ПКАП и дата продуктом который TIB публикует
'SMD'::text AS src_cd,
lower(t2.pm_name)  AS src_node_src_id,
lower(p.pm_name) AS src_schema_src_id,
p.meta_product_name AS target_node_src_id,
p.pm_name AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
lower(p.pm_name)|| '||' || lower(t2.pm_name) AS src_node_id,
p.pm_name || '||' || p.meta_product_name AS target_node_id,
'SMD' AS tgt_node_type_cd,
COALESCE(n.node_type_cd::TEXT,t2.model_element_type_name::text) AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report p
JOIN  s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table t2 ON t2.stock_element_id_ent = p.stock_element_id OR t2.stock_element_id_sch = p.stock_element_id
LEFT JOIN dg_full.meta_node_ref_table n ON  n.node_src_id=lower(t2.pm_name) AND n.schema_src_id=lower(p.pm_name)
WHERE 1=1
 AND (p.data_product_uuid, p.eff_date_ts) in (SELECT pr.data_product_uuid, max(pr.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr group by 1)
 AND p."cluster" ='GP_GM1' 
 AND p.pm_name ILIKE '%tib%'
 AND p.conf_item_product = 'CI02533826'
 UNION all
 SELECT -- свзязи  дата продуктов СМД и  ESPD подписки
 src_cd::text,
src_node_src_id::text,
src_schema_src_id::text,
target_node_src_id::text,
target_schema_src_id::text,
edge_type_src_id::int4,
property_id::int4,
weight::NUMERIC(15,2),
order_by::int4,
is_active::bool,
edge_type_cd::text,
src_node_id::text,
target_node_id::text,
tgt_node_type_cd::text,
src_node_type_cd::text,
enable_dq::text 
FROM temp_smd0 
UNION ALL
 SELECT -- свзязи  потока(подписки SMD) и stg entity
 'SMD'::text AS src_cd,
t.target_node_src_id  AS src_node_src_id,
t.target_schema_src_id AS src_schema_src_id,
n.node_src_id AS target_node_src_id,
n.schema_src_id AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
t.target_schema_src_id|| '||' || t.target_node_src_id AS src_node_id,
n.schema_src_id || '||' || n.node_src_id AS target_node_id,
n.node_type_cd AS tgt_node_type_cd,
'Flow'::text AS src_node_type_cd,
'1'::TEXT AS enable_dq
 FROM temp_smd0 t
  JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND  t.target_node_src_id = n.node_src_id  -- наши подписки из CTL
DISTRIBUTED BY (target_schema_src_id,target_node_src_id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_smd;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_smd - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_tfs - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_tfs AS 
SELECT 
'CTL'::text AS src_cd,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.wf_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.wf_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.wf_nm -- мы кладем в папку tfs
       ELSE '-'
END AS src_node_src_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.category_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.category_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.path_tfs -- мы кладем в папку tfs
       ELSE '-'
END AS src_schema_src_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.wf_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.wf_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.wf_nm -- мы кладем в папку tfs
       ELSE '-'
END AS target_node_src_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.path_tfs   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.path_tfs   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.category_nm -- мы кладем в папку tfs
       ELSE '-'
END AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.category_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.category_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.path_tfs -- мы кладем в папку tfs
       ELSE '-'
END || '||' || CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.wf_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.wf_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.wf_nm -- мы кладем в папку tfs
       ELSE '-'
END AS src_node_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.path_tfs   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.path_tfs   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.category_nm -- мы кладем в папку tfs
       ELSE '-'
END || '||' || CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.wf_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.wf_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.wf_nm -- мы кладем в папку tfs
       ELSE '-'
END AS target_node_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN 'TFS'   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN 'TFS'   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN 'Flow' -- мы кладем в папку tfs
       ELSE '-'
END AS tgt_node_type_cd,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN 'Flow'   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN 'Flow'   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN 'TFS' -- мы кладем в папку tfs
       ELSE '-'
END AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM (
SELECT DISTINCT 
                w.id AS wf_id,
                cc.name_ AS category_nm,
                w.name_ AS wf_nm,
                --------------------
                max(CASE
                    WHEN cp.param::text IN ('file_path_source'::TEXT, 'path_to_local'::TEXT, 'path_to_tfs'::TEXT, 'path_from_local'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS path_tfs
                -------------
             FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN temp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 
            AND w.deleted = false 
            AND (w.profile_id = ANY (ARRAY[329, 334])) 
            AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
          GROUP BY w.id, w.name_, cc.name_
) tt
WHERE tt.path_tfs IS NOT NULL
DISTRIBUTED BY (target_schema_src_id,target_node_src_id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_tfs;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_tfs - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


CREATE TEMPORARY TABLE temp_espd0 AS 
         SELECT 
            w.category_id,
            cc.name_ AS category_nm,
            w.profile_id,
            w.id AS wf_id,
            w.name_ AS wf_nm,
            max(
                CASE
                    WHEN cp.param::text = 'folderName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text) AS folder_nm,
            max(
                CASE
                    WHEN cp.param::text = 'workflowName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text) AS workflow_nm
           FROM  dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN temp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 AND w.deleted = false AND w.profile_id = 150
          GROUP BY w.category_id, cc.name_, w.profile_id, w.id, w.name_
         HAVING (max(
                CASE
                    WHEN cp.param::text = 'folderName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text) || max(
                CASE
                    WHEN cp.param::text = 'workflowName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text)) IS NOT NULL
            DISTRIBUTED BY (wf_nm)    
;
RAISE NOTICE 'temp_espd0';

-- Связь ЕСПД объектов со списком загружаемых stg таблиц 
CREATE TEMPORARY TABLE temp_espd AS 
         SELECT 
            e1.category_id,
            e1.category_nm,
            e1.profile_id,
            e1.wf_id,
            e1.wf_nm,
            e1.folder_nm,
            e1.workflow_nm,
            mel.edge_id,
            current_timestamp AS load_dttm,
            mel.src_cd,
            -1::int4 AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            mel.src_node_src_id,
            mel.src_schema_src_id,
            mel.target_node_src_id,
            mel.target_schema_src_id,
            mel.edge_type_src_id,
            mel.weight,
            mel.order_by,
            mel.is_active
           FROM temp_espd0 e1
           LEFT JOIN s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link mel ON e1.wf_nm::text = mel.src_node_src_id::TEXT -- замена на АС СПОД (Ввод данных)
          WHERE 1=1
            AND mel.src_node_src_id::text ~~ 'ESPD%'::TEXT
            AND mel.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link h1)
            DISTRIBUTED BY (target_schema_src_id,target_node_src_id)    
        ;
RAISE NOTICE 'temp_espd';

CREATE TEMPORARY TABLE temp_wf0 AS 
WITH wf AS (
SELECT 
w.category_id,
w.profile_id,
w.id,
w.name_
FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
WHERE 1 = 1 
AND w.deleted = false 
AND (w.profile_id = ANY (ARRAY[329, 334, 74])) 
            AND (w.id IN ( SELECT cp1.wf_id
                  FROM dg_full.vctl_param cp1 
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- !! '%TIBDS%'::TEXT
                  GROUP BY cp1.wf_id))
)
         SELECT 
            w.category_id,
            cc.name_ AS category_nm,
            w.profile_id,
            w.id AS wf_id,
            w.name_ AS wf_nm,
            cp.param,
            cp.prior_value,
                CASE
                    WHEN cp.param::text in ('tgt_entity_id'::TEXT,'entity_id'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS tgt_entity_id,
                CASE
                    WHEN cp.param::text IN ('stg_schema_name'::TEXT,'stg_schema'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_espd_schema_name,
                CASE
                    WHEN cp.param::text IN ('stg_table_name'::TEXT,'object_name'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_espd_table_name,
                -------------
                CASE
                    WHEN cp.param::text IN ('hive_schema_name'::TEXT,'hive_schema_name_act'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_schema_name,
                CASE
                    WHEN cp.param::text IN ('hive_table_name'::TEXT, 'hive_table_name_act'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_table_name,
                ------
                CASE
                    WHEN cp.param::text = 'hive_schema_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_snp_schema_name,
                CASE
                    WHEN cp.param::text = 'hive_table_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_snp_table_name,
                -------------
                CASE
                    WHEN cp.param::text = 'hive_schema_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_diff_schema_name,
                CASE
                    WHEN cp.param::text = 'hive_table_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_diff_table_name,
                -------------
                CASE
                    WHEN cp.param::text in ('function_schema','ods_schema_name'::TEXT,'ods_schema'::TEXT, 'mart_schema_name'::TEXT ) THEN cp.prior_value -- + 
                    ELSE NULL::character varying
                END::text AS tgt_schema_name,
                CASE
                    WHEN cp.param::text in ('function_name','ods_table_name'::TEXT,'object_name'::TEXT, 'mart_table_name'::TEXT ) THEN cp.prior_value  -- + 
                    ELSE NULL::character varying
                END::text AS tgt_table_name,
                CASE WHEN cp.param::text in ('function_name') THEN 'Function'
                    WHEN cp.param::text in ('ods_table_name'::TEXT,'object_name'::text) THEN 'Table'
                    ELSE NULL::character varying
                END::text AS tgt_node_type_cd,
                CASE
                    WHEN cp.param::text = 'enable_dq'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS enable_dq,
                CASE
                    WHEN cp.param::text = 'column_key_list'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS column_key_list,
                CASE
                    WHEN cp.param::text = 'rin'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS column_rin,
                substring(CASE
                            WHEN cp.param::text = 'rin'::text THEN cp.prior_value
                            ELSE NULL::character varying
                            END::text, ']_(.*?)_POSTGRESQL') AS scenario_cd 
           FROM wf w 
             JOIN temp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp  
               ON w.id = cp.wf_id
          WHERE 1 = 1 
DISTRIBUTED BY (wf_nm);
RAISE NOTICE 'temp_wf0';

CREATE TEMPORARY TABLE temp_wf1 AS 
         SELECT w1.category_id,
            w1.category_nm,
            w1.profile_id,
            w1.wf_id,
            w1.wf_nm,
            max(w1.tgt_entity_id) AS tgt_entity_id,
            max(w1.src_espd_schema_name) AS src_espd_schema_name,
            max(w1.src_espd_table_name) AS src_espd_table_name,
            max(w1.src_hdp_schema_name) AS src_hdp_schema_name,
            max(w1.src_hdp_table_name) AS src_hdp_table_name,
            max(w1.src_hdp_snp_schema_name) AS src_hdp_snp_schema_name,
            max(w1.src_hdp_snp_table_name) AS src_hdp_snp_table_name,
            max(w1.src_hdp_diff_schema_name) AS src_hdp_diff_schema_name,
            max(w1.src_hdp_diff_table_name) AS src_hdp_diff_table_name,
            max(w1.tgt_schema_name) AS tgt_schema_name,
            max(w1.tgt_table_name) AS tgt_table_name,
            max(w1.tgt_node_type_cd) AS tgt_node_type_cd,
            max(w1.enable_dq) AS enable_dq,
            max(w1.column_key_list) AS column_key_list,
            max(w1.scenario_cd) AS scenario_cd
           FROM temp_wf0 w1
          GROUP BY w1.category_id, w1.category_nm, w1.profile_id, w1.wf_id, w1.wf_nm
/*         HAVING (((((((((max(w1.tgt_entity_id) || 
                       max(w1.src_espd_schema_name)) || 
                       max(w1.src_espd_table_name)) || 
                       max(w1.src_hdp_schema_name)) || 
                       max(w1.src_hdp_table_name)) || 
                       max(w1.src_hdp_snp_schema_name)) || 
                       max(w1.src_hdp_snp_table_name)) || 
                       max(w1.src_hdp_diff_schema_name)) || 
                       max(w1.src_hdp_diff_table_name)) || 
                       max(w1.tgt_schema_name)) || 
                       max(w1.tgt_table_name)) || 
                       max(w1.enable_dq)) IS NOT NULL*/
        DISTRIBUTED BY (src_espd_schema_name,src_espd_table_name);
RAISE NOTICE 'temp_wf1';        

CREATE TEMPORARY TABLE temp_simil AS 
SELECT 
tt.scenariocd AS  scenario_cd,
n.schema_src_id, 
n.node_src_id
FROM
(SELECT * FROM s_grnplm_as_cib_gm_meta_tib.etl_bk9scn
WHERE description = 'RUN FUNCTION'
UNION 
SELECT * FROM s_grnplm_as_cib_gm_meta.etl_bk9scn
WHERE description = 'RUN FUNCTION'
) tt
CROSS JOIN dg_full.meta_node_ref_table n 
WHERE 1=1
AND similarity( tt.sql_line , n.schema_src_id::Text || '||'::TEXT || n.node_src_id) >= 0.5
DISTRIBUTED BY (scenario_cd);
RAISE NOTICE 'temp_simil';        

CREATE TEMPORARY TABLE temp_wf AS 
         SELECT 
            w2.category_id,
            w2.category_nm,
            w2.profile_id,
            w2.wf_id,
            w2.wf_nm,
            w2.tgt_entity_id,
            w2.src_espd_schema_name,
            w2.src_espd_table_name,
            w2.src_hdp_schema_name,
            w2.src_hdp_table_name,
            w2.src_hdp_snp_schema_name,
            w2.src_hdp_snp_table_name,
            w2.src_hdp_diff_schema_name,
            w2.src_hdp_diff_table_name,
            COALESCE(w2.tgt_schema_name,s.schema_src_id) AS tgt_schema_name,
            COALESCE(w2.tgt_table_name, s.node_src_id ) AS tgt_table_name,
            COALESCE(w2.tgt_node_type_cd,'Function') AS tgt_node_type_cd,
            w2.enable_dq,
            w2.column_key_list,
            w2.scenario_cd
           FROM temp_wf1 w2
LEFT JOIN temp_simil s ON s.scenario_cd = w2.scenario_cd
        DISTRIBUTED BY (src_espd_schema_name,src_espd_table_name);
RAISE NOTICE 'temp_wf';        



CREATE TEMPORARY TABLE temp_final AS 
         SELECT DISTINCT 
            te.wf_id,
            es.category_nm AS espd_src_schema_src_id,
            es.wf_nm AS espd_src_node_src_id,
            es.target_node_src_id AS espd_target_node_src_id,
            es.target_schema_src_id AS espd_target_schema_src_id,
            --
            te.src_espd_schema_name AS wf_src_schema_src_id,
            te.src_espd_table_name AS wf_src_node_src_id,
            --
            te.src_hdp_schema_name AS wf_src_h_schema_src_id,
            te.src_hdp_table_name AS wf_src_h_node_src_id,
            --
            te.src_hdp_snp_schema_name AS wf_src_hs_schema_src_id,
            te.src_hdp_snp_table_name AS wf_src_hs_node_src_id,
            --
            te.src_hdp_diff_schema_name AS wf_src_hd_schema_src_id,
            te.src_hdp_diff_table_name AS wf_src_hd_node_src_id,
            --
            te.category_nm AS wf_target_schema_src_id,
            te.wf_nm AS wf_target_node_src_id,
            te.category_nm AS wf1_src_schema_src_id,
            te.wf_nm AS wf1_src_node_src_id,
            CASE WHEN POSITION('/' IN reverse(e."path")) <> 0 AND POSITION(e.name_::TEXT IN e."path") <> 0 
                 THEN substring(e."path" FROM 1 FOR (length(e."path") - POSITION('/' IN reverse(e."path")) + 1 ) - 1) 
                 ELSE DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e.name_ , 'xx'::TEXT, e."path" ) END AS wf1_target_schema_src_id,
            e.name_ AS wf1_target_node_src_id,
            -- DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path") AS wf2_src_schema_src_id,
            -- e.name_ AS wf2_src_node_src_id, -- entity -> table
            te.category_nm AS wf2_src_schema_src_id,
            te.wf_nm       AS wf2_src_node_src_id, -- change chain wf -> table
            te.tgt_schema_name AS wf2_target_schema_src_id,
            te.tgt_table_name AS wf2_target_node_src_id,
            te.tgt_node_type_cd AS wf2_tgt_node_type_cd,
            te.enable_dq,
            te.column_key_list
           FROM temp_wf te
             LEFT JOIN temp_espd es ON es.target_schema_src_id::text = te.src_espd_schema_name AND es.target_node_src_id::text = te.src_espd_table_name
             LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity e ON te.tgt_entity_id = e.id::TEXT
        DISTRIBUTED BY (wf_src_schema_src_id, wf_src_node_src_id)
        ;
RAISE NOTICE 'temp_final';    

-- Entity (trigger) -> Wf
CREATE TEMPORARY TABLE temp_wf01 AS 
WITH wf AS (
SELECT 
w.category_id,
w.profile_id,
w.id,
w.name_
FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
WHERE 1 = 1 
AND w.deleted = false 
AND (w.profile_id = ANY (ARRAY[329, 334, 74])) 
            AND (w.id IN ( SELECT cp1.wf_id
                  FROM dg_full.vctl_param cp1 
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
)
SELECT 
w.category_id,
cc.name_ AS wf_target_schema_src_id,
w.profile_id,
w.id AS wf_id,
w.name_ AS wf_target_node_src_id,
e.entity_id , e.stat_id , e.stat_type ,
CASE WHEN POSITION('/' IN reverse(ee."path")) <> 0 AND POSITION(ee.name_::TEXT IN ee."path") <> 0 
                 THEN substring(ee."path" FROM 1 FOR (length(ee."path") - POSITION('/' IN reverse(ee."path")) + 1 ) - 1) 
                 ELSE DECODE(ee."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, ee.name_ , 'xx'::TEXT, ee."path" ) 
END AS entity_src_schema_src_id,
ee.name_ AS entity_src_node_src_id
FROM wf w 
JOIN temp_meta_sg_category cc 
  ON w.category_id = cc.id
JOIN dg_full.vctl_wf_event_sched e ON e.wf_id = w.id::int8::TEXT
JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity ee ON e.entity_id = ee.id::int8::TEXT 
WHERE 1 = 1 
DISTRIBUTED BY (wf_target_schema_src_id, wf_target_node_src_id);
RAISE NOTICE 'temp_wf01';

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_edge_ctl_link - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_edge_ctl_link AS     
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.espd_src_schema_src_id::text AS src_schema_src_id,
    f.espd_src_node_src_id::text AS src_node_src_id,
    f.espd_target_schema_src_id::text AS target_schema_src_id,
    f.espd_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.espd_src_schema_src_id::text || '||'::text) || f.espd_src_node_src_id::text AS src_node_id,
    (f.espd_target_schema_src_id::text || '||'::text) || f.espd_target_node_src_id::text AS target_node_id,
    'Table'::text AS tgt_node_type_cd,
    'Flow'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.espd_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.espd_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.espd_target_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.espd_target_schema_src_id::TEXT,'') <> ''
  GROUP BY 
    f.wf_id,
    f.espd_src_schema_src_id::text ,
    f.espd_src_node_src_id::text ,
    f.espd_target_schema_src_id::text,
    f.espd_target_node_src_id::text ,
    (f.espd_src_schema_src_id || '||'::text) || f.espd_src_node_src_id::text ,
    (f.espd_target_schema_src_id::text || '||'::text) || f.espd_target_node_src_id::TEXT,
     f.enable_dq,
    f.column_key_list
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_schema_src_id::text AS src_schema_src_id,
    f.wf_src_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_schema_src_id || '||'::text) || f.wf_src_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
     f.wf_id,
     f.wf_src_schema_src_id::text, 
     f.wf_src_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_schema_src_id::text || '||'::text) || f.wf_src_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::TEXT,
     f.enable_dq,
    f.column_key_list
-------------------------
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_h_schema_src_id::text AS src_schema_src_id,
    f.wf_src_h_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_h_schema_src_id || '||'::text) || f.wf_src_h_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_h_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_h_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
     f.wf_src_h_schema_src_id::text, 
     f.wf_src_h_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_h_schema_src_id::text || '||'::text) || f.wf_src_h_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
---------------------------     
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_hs_schema_src_id::text AS src_schema_src_id,
    f.wf_src_hs_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_hs_schema_src_id || '||'::text) || f.wf_src_hs_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_hs_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_hs_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
     f.wf_src_hs_schema_src_id::text, 
     f.wf_src_hs_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_hs_schema_src_id::text || '||'::text) || f.wf_src_hs_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
---------------------------     
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_hd_schema_src_id::text AS src_schema_src_id,
    f.wf_src_hd_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_hd_schema_src_id || '||'::text) || f.wf_src_hd_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_hd_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_hd_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
     f.wf_src_hd_schema_src_id::text, 
     f.wf_src_hd_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_hd_schema_src_id::text || '||'::text) || f.wf_src_hd_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
---------------------------     
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf1_src_schema_src_id::text AS src_schema_src_id,
    f.wf1_src_node_src_id::text AS src_node_src_id,
    f.wf1_target_schema_src_id::text AS target_schema_src_id,
    f.wf1_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf1_src_schema_src_id::text || '||'::text) || f.wf1_src_node_src_id::text AS src_node_id,
    (f.wf1_target_schema_src_id::text || '||'::text) || f.wf1_target_node_src_id::text AS target_node_id,
    'Entity'::text AS tgt_node_type_cd,
    'Flow'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf1_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf1_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf1_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf1_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
      f.wf1_src_schema_src_id::text, 
      f.wf1_src_node_src_id::text, 
      f.wf1_target_schema_src_id::text, 
      f.wf1_target_node_src_id::text, 
      (f.wf1_src_schema_src_id::text || '||'::text) || f.wf1_src_node_src_id::text, (f.wf1_target_schema_src_id::text || '||'::text) || f.wf1_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf2_src_schema_src_id::text AS src_schema_src_id,
    f.wf2_src_node_src_id::text AS src_node_src_id,
    f.wf2_target_schema_src_id::text AS target_schema_src_id,
    f.wf2_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf2_src_schema_src_id::text || '||'::text) || f.wf2_src_node_src_id::text AS src_node_id,
    (f.wf2_target_schema_src_id || '||'::text) || f.wf2_target_node_src_id AS target_node_id,
    f.wf2_tgt_node_type_cd AS tgt_node_type_cd,
    'Flow'::text AS src_node_type_cd, -- 'Entity' - change chain Wf -> Table
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf2_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf2_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf2_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf2_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
    f.wf2_src_schema_src_id::text, 
    f.wf2_src_node_src_id::text, 
    f.wf2_target_schema_src_id::text, 
    f.wf2_target_node_src_id::text, 
    (f.wf2_src_schema_src_id::text || '||'::text) || f.wf2_src_node_src_id::text, (f.wf2_target_schema_src_id::text || '||'::text) || f.wf2_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list,
     f.wf2_tgt_node_type_cd
UNION      
SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    -1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.entity_src_schema_src_id::text AS src_schema_src_id,
    f.entity_src_node_src_id::text   AS src_node_src_id,
    f.wf_target_schema_src_id::text  AS target_schema_src_id,
    f.wf_target_node_src_id::text    AS target_node_src_id,
    7 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Влияет на запуск'::text AS edge_type_cd,
    (f.entity_src_schema_src_id::text || '||'::text) || f.entity_src_node_src_id::text AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Entity'::text AS src_node_type_cd,
    NULL::text AS enable_dq ,
    NULL::text AS column_key_list
FROM temp_wf01 f
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_edge_ctl_link;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_edge_ctl_link - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_edge_qs_link - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_edge_qs_link AS 
WITH tt_main AS (
SELECT 
tt.*
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  ELSE substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  END  AS schema_src_id
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  ELSE substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  END AS node_src_id
, CASE WHEN  tt.lng_object_type = 'TXT' THEN 8
       WHEN  tt.lng_object_type = 'EXCEL' THEN 8
       WHEN  tt.lng_object_type = 'SQL' THEN 1
       WHEN  tt.lng_object_type = 'QVD' THEN 6
       WHEN  tt.lng_object_type = 'CSV' THEN 8
       WHEN  tt.lng_object_type = 'APP' THEN 13
  END AS  node_type_src_id
, CASE WHEN  tt.lng_object_type = 'TXT' THEN 'Excel\CSV'
       WHEN  tt.lng_object_type = 'EXCEL' THEN 'Excel\CSV'
       WHEN  tt.lng_object_type = 'SQL' THEN 'Table'
       WHEN  tt.lng_object_type = 'QVD' THEN 'QVD'
       WHEN  tt.lng_object_type = 'CSV' THEN 'Excel\CSV'
       WHEN  tt.lng_object_type = 'APP' THEN'Application QS'
  END AS  node_type_cd
FROM (
SELECT DISTINCT  
l.app_key, l.lng_flow , COALESCE(l.lng_src_flag,'-') AS lng_src_flag, l.lng_object_type , l.lng_application
, CASE 
  WHEN POSITION ('_20' IN l.lng_object) <> 0  THEN regexp_replace(REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://'),'\_20.*?\.','.')
  ELSE REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://') END AS lng_object_1
FROM s_grnplm_as_cib_gm_ods_qlik.lineage l 
WHERE 1=1
AND lng_object NOT LIKE '%ArchivedLogsFolder%'
AND lng_object NOT LIKE '%ServerLogFolder%'
AND lng_object NOT LIKE '%/Meta/AppSrc/%'
AND l.lng_application NOT LIKE '%Find Applications SQL Sources%'
) tt
)
, tt_edge AS (
SELECT 
'QS' AS src_cd,
t1.node_src_id AS src_node_src_id,
t1.schema_src_id AS src_schema_src_id,
t1.lng_application AS target_node_src_id,
t1.lng_flow AS target_schema_src_id,
2 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Входит в'::TEXT AS edge_type_cd,
t1.schema_src_id || '||' || t1.node_src_id AS src_node_id,
t1.lng_flow || '||' || t1.lng_application AS target_node_id,
'Application QS'::text AS tgt_node_type_cd,
t1.node_type_cd AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM tt_main t1
WHERE lng_src_flag = '1' -- приложение - потребитель
UNION 
SELECT 
'QS' AS src_cd,
t2.lng_application AS src_node_src_id,
t2.lng_flow AS src_schema_src_id,
t2.node_src_id AS target_node_src_id,
t2.schema_src_id AS target_schema_src_id,
5 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Результат'::TEXT AS edge_type_cd,
t2.lng_flow || '||' || t2.lng_application AS src_node_id,
t2.schema_src_id || '||' || t2.node_src_id AS target_node_id,
t2.node_type_cd AS tgt_node_type_cd,
'Application QS'::text AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM tt_main t2
WHERE lng_src_flag = '-' -- приложение - источник
)
SELECT 
e.src_cd,
e.src_node_src_id,
e.src_schema_src_id,
e.target_node_src_id,
e.target_schema_src_id,
e.edge_type_src_id,
e.property_id,
e.weight,
e.order_by,
e.is_active,
e.edge_type_cd,
e.src_node_id,
e.target_node_id,
e.tgt_node_type_cd,
e.src_node_type_cd,
e.enable_dq 
FROM tt_edge e
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_edge_qs_link;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_edge_qs_link - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


/*
 CREATE TEMPORARY TABLE temp_p AS 
         SELECT 
            (pgn.nspname::text || '||'::text) || pgp.proname::text AS target_node_id,
            pgn.nspname,
            replace(pgp.proname::text, '"'::text, ''::text) AS proname,
            replace(regexp_replace(btrim(pgp.prosrc), '[\n\r\t\v]+'::text, ''::text), '"'::text, ''::text) AS prosrc
           FROM pg_proc pgp
             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s1 ON pgn.nspname::text = s1.schema_src_id::text
          WHERE 1 = 1
        DISTRIBUTED BY (nspname);
*/

CREATE TEMPORARY TABLE temp_p 
WITH (APPENDONLY=true, COMPRESSTYPE=zlib, COMPRESSLEVEL=5) AS 
SELECT 
    pgn.nspname::text || '||' || pgp.proname::text AS target_node_id,
    pgn.nspname,
    regexp_replace(pgp.proname::text, '"', '', 'g') AS proname,
    regexp_replace(
        regexp_replace(
            btrim(pgp.prosrc), 
            '[\n\r\t\v]+', 
            ' ', 
            'g'
        ), 
        '"', 
        '', 
        'g'
    ) AS prosrc
FROM pg_proc pgp
JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
WHERE EXISTS (
    SELECT 1 
    FROM dg_full.meta_schema_ref_table s1 
    WHERE s1.schema_src_id = pgn.nspname::text
)
DISTRIBUTED RANDOMLY;

ANALYZE temp_p; 
CREATE INDEX ON temp_p USING gin(prosrc gin_trgm_ops);
RAISE NOTICE 'temp_p';

/*
 CREATE TEMPORARY TABLE temp_tt AS 
         SELECT 
            t.schema_src_id,
            replace(t.node_src_id::text, '"'::text, ''::text) AS node_src_id,
            p.nspname,
            replace(p.proname, '"'::text, ''::text) AS proname,
            p.prosrc,
                CASE
                    WHEN lower(p.prosrc) like ((('%insert into '::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::TEXT || '%') THEN 5
                    ELSE NULL::integer
                END AS ww5,
                CASE
                    WHEN lower(p.prosrc) like (('%v_tgt_table_name text default '''::text || t.node_src_id::text) || ''';%'::text)
                     AND lower(p.prosrc) like (('%v_tgt_schema_name text default '''::text || t.schema_src_id::text) || ''';%'::text) THEN 5
                    ELSE NULL::integer
                END AS ww51,
                CASE
                    WHEN lower(p.prosrc) like (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || '%'::text) 
                      OR lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || ' %'::text) 
                      OR lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || '(%'::text) THEN 4
                    ELSE NULL::integer
                END AS ww4,
            t.is_active,
            t.node_type_cd AS src_node_type_cd,
            'Function'::text AS tgt_node_type_cd
           FROM dg_full.meta_node_ref_table t
             CROSS JOIN temp_p p
          WHERE 1 = 1 
            --- !!! AND t.src_cd = 'GP'::text 
            AND ((t.schema_src_id::text || '||'::text) || t.node_src_id::text) <> p.target_node_id
            AND COALESCE(t.schema_src_id::TEXT,'') <> '' 
            AND COALESCE(t.node_src_id::TEXT,'') <> ''
DISTRIBUTED BY (schema_src_id, node_src_id );

*/

CREATE TEMPORARY TABLE temp_tt 
WITH (APPENDONLY=true, COMPRESSTYPE=zlib, COMPRESSLEVEL=5) AS 
SELECT 
    t.schema_src_id,
    regexp_replace(t.node_src_id::text, '"', '', 'g') AS node_src_id,
    p.nspname,
    regexp_replace(p.proname, '"', '', 'g') AS proname,
    p.prosrc,
    CASE
        WHEN p.prosrc ILIKE '%insert into ' || t.schema_src_id || '.' || t.node_src_id || '%' THEN 5
        ELSE NULL
    END AS ww5,
    CASE
        WHEN p.prosrc ILIKE '%v_tgt_table_name text default ''' || t.node_src_id || ''';%'
         AND p.prosrc ILIKE '%v_tgt_schema_name text default ''' || t.schema_src_id || ''';%' THEN 5
        ELSE NULL
    END AS ww51,
    CASE
        WHEN p.prosrc ILIKE '%' || t.schema_src_id || '.' || t.node_src_id || '%' 
         AND (p.prosrc ILIKE '%' || t.schema_src_id || '.' || t.node_src_id || ' %' 
           OR p.prosrc ILIKE '%' || t.schema_src_id || '.' || t.node_src_id || '(%') THEN 4
        ELSE NULL
    END AS ww4,
    t.is_active,
    t.node_type_cd AS src_node_type_cd,
    'Function'::text AS tgt_node_type_cd
FROM dg_full.meta_node_ref_table t
CROSS JOIN temp_p p
WHERE t.schema_src_id::TEXT <> ''
  AND t.node_src_id::TEXT <> ''
  AND (t.schema_src_id::text || '||' || t.node_src_id::text) <> p.target_node_id
  -- Добавить если нужно: AND t.src_cd = 'GP'
DISTRIBUTED RANDOMLY;

ANALYZE temp_tt;
RAISE NOTICE 'temp_tt';


CREATE TEMPORARY TABLE temp_tt1 AS 
         SELECT
                CASE
                    WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || '(%'::text) THEN 6
                    WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || ' %'::text) THEN 8
                    WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || '%'::text) THEN 8
                    WHEN etl.sql_line::text ~~ ((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) THEN 8
                    ELSE NULL::integer
                END AS edge_type_src_id,
            replace(src.node_src_id::text, '"'::text, ''::text)::text AS src_node_src_id,
            src.schema_src_id::text AS src_schema_src_id,
            replace(tgt.node_src_id::text, '"'::text, ''::text)::text AS target_node_src_id,
            tgt.schema_src_id::text AS target_schema_src_id,
            src.is_active,
            tgt.node_type_cd AS tgt_node_type_cd,
            src.node_type_cd AS src_node_type_cd
           FROM (SELECT * FROM s_grnplm_as_cib_gm_meta.etl_bk9scn t1
                 UNION 
                 SELECT * FROM s_grnplm_as_cib_gm_meta_tib.etl_bk9scn t2
                ) etl
             JOIN dg_full.meta_node_ref_table tgt ON etl.scenariocd::text = replace(tgt.node_src_id::text, '_'::text, ''::text)
             CROSS JOIN dg_full.meta_node_ref_table src
          WHERE 1 = 1
DISTRIBUTED BY (src_node_src_id,src_schema_src_id,target_node_src_id,target_schema_src_id) ;
RAISE NOTICE 'temp_tt1';

/* Массив доп.свойств */
CREATE TEMPORARY TABLE tmp_pp AS
SELECT m.object_src_id,
       m.schema_src_id,
       m.property_type_src_id,
       m.property_val 
FROM dg_full.vmeta_property_hsat m
WHERE (m.load_dttm,m.object_src_id,m.schema_src_id, m.property_type_src_id) 
IN (SELECT 
       max(m0.load_dttm) AS max,
       m0.object_src_id,
       m0.schema_src_id,
       m0.property_type_src_id
    FROM dg_full.vmeta_property_hsat m0
    GROUP BY m0.object_src_id, m0.schema_src_id, m0.property_type_src_id)
DISTRIBUTED BY (schema_src_id, object_src_id, property_type_src_id)
;
RAISE NOTICE 'tmp_pp';


CREATE TEMPORARY TABLE temp_bb AS 
         SELECT DISTINCT
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            replace(ns_src.nspname::text, '"'::text, ''::text)::text AS src_schema_src_id,
            t.relname::text AS src_node_src_id,
            ns_tgt.nspname::text AS target_schema_src_id,
            replace(v.relname::text, '"'::text, ''::text)::text AS target_node_src_id,
            2 AS edge_type_src_id,
            1 AS weight,
            1 AS order_by,
            CASE
             WHEN coalesce(pp.property_val,'1') = '1'::text THEN TRUE
             WHEN coalesce(pp.property_val,'1') = '0'::text THEN FALSE
             ELSE FALSE
            END AS is_active,
                CASE
                    WHEN v.relkind = 'v'::"char" THEN 'View'::text
                    WHEN v.relkind = 'm'::"char" THEN 'View'::text
                    WHEN v.relkind = 'p'::"char" THEN 'Table'::text
                    WHEN v.relkind = 'r'::"char" THEN 'Table'::text
                    WHEN v.relkind = 't'::"char" THEN 'Table'::text
                    WHEN v.relkind = 'f'::"char" THEN 'Function'::text
                    ELSE v.relkind::text
                END AS tgt_node_type_cd,
                CASE
                    WHEN t.relkind = ANY (ARRAY['v'::"char", 'm'::"char"]) THEN 'View'::text
                    WHEN v.relkind = ANY (ARRAY['p'::"char", 'r'::"char", 't'::"char"]) THEN 'Table'::text
                    WHEN t.relkind = ANY (ARRAY['p'::"char", 'r'::"char", 't'::"char"]) THEN 'Table'::text
                    WHEN t.relkind = 'f'::"char" THEN 'Function'::text
                    ELSE t.relkind::text
                END AS src_node_type_cd
           FROM pg_depend d
             JOIN pg_rewrite r ON r.oid = d.objid
             JOIN pg_class v ON v.oid = r.ev_class
             JOIN pg_namespace ns_tgt ON ns_tgt.oid = v.relnamespace
             JOIN dg_full.meta_schema_ref_table s ON ns_tgt.nspname::text = s.schema_src_id::text
             JOIN pg_class t ON t.oid = d.refobjid
             JOIN pg_namespace ns_src ON ns_src.oid = t.relnamespace
             LEFT JOIN tmp_pp pp ON pp.object_src_id::text = t.relname::text AND pp.schema_src_id::text = ns_src.nspname::text AND pp.property_type_src_id = 6
          WHERE 1 = 1 
            AND (v.relkind = ANY (ARRAY['p'::"char", 't'::"char", 'r'::"char", 'v'::"char", 'm'::"char", 'f'::"char"])) 
            AND d.classid = 'pg_rewrite'::regclass::oid 
            AND (d.refclassid = 'pg_class'::regclass::oid OR d.refclassid = 'pg_proc'::regclass::oid) AND NOT v.oid = d.refobjid AND ns_src.nspname::text <> 'pg_catalog'::text AND ns_tgt.nspname::text <> 'pg_catalog'::text
        UNION ALL
         SELECT DISTINCT
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.nspname
                    ELSE tt.schema_src_id
                END::text AS src_schema_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.proname
                    ELSE tt.node_src_id
                END::text AS src_node_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.schema_src_id
                    ELSE tt.nspname
                END::text AS target_schema_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.node_src_id
                    ELSE tt.proname
                END::text AS target_node_src_id,
            COALESCE(tt.ww5, tt.ww51, tt.ww4) AS edge_type_src_id,
            1 AS weight,
            1 AS order_by,
            tt.is_active,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.src_node_type_cd::text
                    ELSE tt.tgt_node_type_cd
                END AS tgt_node_type_cd,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.tgt_node_type_cd::character varying
                    ELSE tt.src_node_type_cd
                END AS src_node_type_cd
           FROM temp_tt tt
          WHERE 1 = 1 
          AND COALESCE(tt.ww4, tt.ww5, tt.ww51) IS NOT NULL 
          AND tt.nspname::text <> 'pg_catalog'::text 
          AND tt.schema_src_id::text <> 'pg_catalog'::text
        UNION ALL
         SELECT DISTINCT 
            current_timestamp AS load_dttm,
            d.src_cd,
            -1::integer AS wf_load_id,
            d.src_schema_src_id::text,
            replace(d.src_node_src_id::text, '"'::text, ''::text)::text AS src_node_src_id,
            d.target_schema_src_id::text,
            replace(d.target_node_src_id::text, '"'::text, ''::text)::text AS target_node_src_id,
            d.edge_type_src_id,
            d.weight::integer AS weight,
            d.order_by,
            d.is_active,
            ntt.node_type_cd::text AS tgt_node_type_cd,
            nts.node_type_cd::text AS src_node_type_cd
           FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link d -- замена на АС СПОД (Ввод данных)
             LEFT JOIN dg_full.meta_node_ref_table ns ON d.src_schema_src_id::text = ns.schema_src_id::text 
                                                                           AND d.src_node_src_id::text = ns.node_src_id::text
             LEFT JOIN dg_full.meta_node_type_ref_table nts ON ns.node_type_src_id = nts.node_type_src_id
             LEFT JOIN dg_full.meta_node_ref_table nt ON d.target_schema_src_id::text = nt.schema_src_id::text 
                                                                           AND d.target_node_src_id::text = nt.node_src_id::text
             LEFT JOIN dg_full.meta_node_type_ref_table ntt ON nt.node_type_src_id = ntt.node_type_src_id
           WHERE 1=1
             AND d.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link h1)
             AND d.src_cd::text IN ( 'QS','Navi','SMD')
        DISTRIBUTED BY (src_schema_src_id, src_node_src_id,target_schema_src_id, target_node_src_id);
RAISE NOTICE 'temp_bb';

-- dg_full.vmeta_edge_link source
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_edge_link - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_edge_link AS 
 SELECT DISTINCT 
    -1::bigint AS edge_id,
    bb.load_dttm,
    bb.src_cd,
    bb.wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    bb.src_schema_src_id::text AS src_schema_src_id,
    bb.src_node_src_id::text,
    bb.target_schema_src_id::text,
    bb.target_node_src_id::text AS target_node_src_id,
    bb.edge_type_src_id,
    bb.weight,
    bb.order_by,
        CASE
            WHEN bb.src_node_src_id ~~ '%save_step_to_logs%'::text OR bb.target_node_src_id ~~ '%save_step_to_logs%'::text THEN false
            ELSE bb.is_active
        END AS is_active,
    ee.edge_type_cd,
    (bb.src_schema_src_id || '||'::text) || bb.src_node_src_id::text AS src_node_id,
    (bb.target_schema_src_id::text || '||'::text) || bb.target_node_src_id::text AS target_node_id,
    bb.tgt_node_type_cd,
    bb.src_node_type_cd,
    NULL::TEXT AS enable_dq , 
    NULL::TEXT AS column_key_list
   FROM temp_bb bb
     JOIN dg_full.meta_edge_type_ref_table ee ON bb.edge_type_src_id = ee.edge_type_src_id
  GROUP BY bb.load_dttm, bb.src_cd, bb.wf_load_id,  
           bb.src_schema_src_id::text, bb.src_node_src_id::text, bb.target_schema_src_id::text, bb.target_node_src_id::text, bb.edge_type_src_id, bb.weight, bb.order_by,
        CASE
            WHEN bb.src_node_src_id ~~ '%save_step_to_logs%'::text OR bb.target_node_src_id ~~ '%save_step_to_logs%'::text THEN false
            ELSE bb.is_active
        END, ee.edge_type_cd, 
        (bb.src_schema_src_id || '||'::text) || bb.src_node_src_id::text, 
        (bb.target_schema_src_id::text || '||'::text) || bb.target_node_src_id, bb.tgt_node_type_cd, bb.src_node_type_cd
UNION ALL 
 SELECT 
    cc.edge_id,
    cc.load_dttm,
    cc.src_cd,
    cc.wf_load_id,
    cc.eff_from_dttm,
    cc.eff_to_dttm,
    cc.last_seen_dttm,
    cc.src_schema_src_id::text,
    cc.src_node_src_id::text,
    cc.target_schema_src_id::text,
    cc.target_node_src_id::text,
    cc.edge_type_src_id,
    cc.weight,
    cc.order_by,
    cc.is_active,
    cc.edge_type_cd::character varying(100) AS edge_type_cd,
    cc.src_node_id::text,
    cc.target_node_id::text,
    cc.tgt_node_type_cd,
    cc.src_node_type_cd,
    cc.enable_dq , 
    cc.column_key_list
   FROM temp_meta_edge_ctl_link cc
UNION ALL 
 SELECT 
    -1::int8 AS edge_id,
    current_timestamp AS load_dttm,
    q.src_cd,
    -1::int8 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm,
    q.src_schema_src_id::text,
    q.src_node_src_id::text,
    q.target_schema_src_id::text,
    q.target_node_src_id::text,
    q.edge_type_src_id,
    q.weight,
    q.order_by,
    q.is_active,
    q.edge_type_cd::character varying(100) AS edge_type_cd,
    q.src_node_id::text,
    q.target_node_id::text,
    q.tgt_node_type_cd,
    q.src_node_type_cd,
    q.enable_dq ,
    NULL::TEXT AS column_key_list
   FROM temp_meta_edge_qs_link q
UNION   ALL    
SELECT 
    -1::int8 AS edge_id,
    current_timestamp AS load_dttm,
    s.src_cd, 
    -1::int8 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm,
    s.src_schema_src_id,
    s.src_node_src_id,
    s.target_schema_src_id,
    s.target_node_src_id,
    s.edge_type_src_id,
    s.weight,
    s.order_by,
    s.is_active,
    s.edge_type_cd::character varying(100) AS edge_type_cd,
    s.src_node_id::text,
    s.target_node_id::text,
    s.tgt_node_type_cd,
    s.src_node_type_cd,
    s.enable_dq ,
    NULL::text AS column_key_list
FROM temp_smd s
UNION   ALL    
SELECT 
    -1::int8 AS edge_id,
    current_timestamp AS load_dttm,
    t.src_cd, 
    -1::int8 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm,
    t.src_schema_src_id,
    t.src_node_src_id,
    t.target_schema_src_id,
    t.target_node_src_id,
    t.edge_type_src_id,
    t.weight,
    t.order_by,
    t.is_active,
    t.edge_type_cd::character varying(100) AS edge_type_cd,
    t.src_node_id::text,
    t.target_node_id::text,
    t.tgt_node_type_cd,
    t.src_node_type_cd,
    t.enable_dq ,
    NULL::text AS column_key_list
FROM temp_tfs t
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_edge_link;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_edge_link - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
   
DROP TABLE IF EXISTS temp_tt;
DROP TABLE IF EXISTS temp_tt1;
DROP TABLE IF EXISTS temp_bb;
DROP TABLE IF EXISTS temp_pp;
   
/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_edge_link';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_edge_link;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_edge_link'|| chr(9) || v_deleted_row::text;


/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_edge_link ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_edge_link 
(edge_id,
    load_dttm,
    src_cd,
    wf_load_id,
    eff_from_dttm,
    eff_to_dttm,
    last_seen_dttm,
    src_schema_src_id,
    src_node_src_id,
    target_schema_src_id,
    target_node_src_id,
    edge_type_src_id,
    weight,
    order_by,
    is_active,
    edge_type_cd,
    src_node_id,
    target_node_id,
    tgt_node_type_cd,
    src_node_type_cd,
    enable_dq ,
    column_key_list
    )
SELECT  
    l.edge_id,
    l.load_dttm,
    l.src_cd,
    l.wf_load_id,
    l.eff_from_dttm,
    l.eff_to_dttm,
    l.last_seen_dttm,
    l.src_schema_src_id,
    l.src_node_src_id,
    l.target_schema_src_id,
    l.target_node_src_id,
    l.edge_type_src_id,
    l.weight,
    l.order_by,
    l.is_active,
    l.edge_type_cd,
    l.src_node_id,
    l.target_node_id,
    l.tgt_node_type_cd,
    l.src_node_type_cd,
    l.enable_dq ,
    l.column_key_list
FROM temp_meta_edge_link l
--!! JOIN dg_full.meta_schema_ref_table ss ON l.src_schema_src_id = ss.schema_src_id
--!! JOIN dg_full.meta_schema_ref_table st ON l.target_schema_src_id = st.schema_src_id
;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_edge_link' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_edge_link - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_edge_qs_link;
DROP TABLE IF EXISTS temp_meta_edge_ctl_link;
DROP TABLE IF EXISTS temp_meta_edge_link;
DROP TABLE IF EXISTS temp_meta_sg_category;
DROP TABLE IF EXISTS temp_espd0;
DROP TABLE IF EXISTS temp_espd;
DROP TABLE IF EXISTS temp_wf0;
DROP TABLE IF EXISTS temp_wf1;
DROP TABLE IF EXISTS temp_wf;
DROP TABLE IF EXISTS temp_wf01;
DROP TABLE IF EXISTS temp_final;
DROP TABLE IF EXISTS temp_simil;
DROP TABLE IF EXISTS temp_p;
DROP TABLE IF EXISTS temp_pp;
DROP TABLE IF EXISTS temp_smd0;
DROP TABLE IF EXISTS temp_smd;
DROP TABLE IF EXISTS temp_tfs;


v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;











$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_edge_link_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	

/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-01-13 Add chain entity -> wf -> entity
 * 2025-04-11 Add QS edge links
 * 2025-11-07 Add SMD
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_edge_link';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_edge_link';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

-- dg_full.vmeta_sg_category source
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_sg_category - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_sg_category AS 
WITH RECURSIVE sg_category(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parentid   AS parent_id,
            g.name::TEXT AS name_,
            1 AS depth,
            ARRAY[g.name::TEXT] AS path,
            false AS cycle,
            g.name AS root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g -- s_grnplm_as_cib_gm_stg_espd.ctl_category g
          WHERE 1 = 1 
            AND g.parentid = 0 
            AND g.id in (1764 ,1964)
            AND g.deleted = false
        UNION ALL
         SELECT g1.id,
            g1.parentid AS parent_id,
            g1.name::TEXT AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name::TEXT,
            g1.name::TEXT = ANY (p.path),
            p.root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g1 -- s_grnplm_as_cib_gm_stg_espd.ctl_category g1
             JOIN sg_category p ON p.id = g1.parentid
          WHERE 1 = 1 AND NOT p.cycle
        )
 SELECT sg_category.id,
    sg_category.parent_id,
    sg_category.name_,
    sg_category.depth,
    sg_category.path,
    sg_category.cycle,
    sg_category.root_name_id
   FROM sg_category
DISTRIBUTED BY (id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_sg_category;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_sg_category - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_smd0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_smd0 AS 
SELECT -- свзязи  дата продуктов СМД и  ESPD подписки
 'SMD'::text AS src_cd,
lower(pr.meta_product_name)  AS src_node_src_id,
lower(pr.pm_name) AS src_schema_src_id,
s.core_uuid AS target_node_src_id,
n.schema_src_id AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
lower(pr.pm_name)|| '||' || lower(pr.meta_product_name) AS src_node_id,
n.schema_src_id || '||' || s.core_uuid AS target_node_id,
'Flow' AS tgt_node_type_cd,
'SMD'::text AS src_node_type_cd,
'1'::TEXT AS enable_dq 
 FROM s_grnplm_as_cib_gm_stg_espd.v_smd_subscription_report s -- подписки
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_subscr_dp_rel r ON  s.subscription_uuid = r.subscription_uuid
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr  ON pr.stock_element_id = r.stock_element_id_sch
JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND s.subscription_uuid = n.node_src_id -- наши подписки из CTL
WHERE 1=1
--AND (pr.data_product_uuid, pr.eff_date_ts) in (SELECT pr1.data_product_uuid, max(pr1.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr1 group by 1)
AND s.subscription_status_display_name = 'Активна'
DISTRIBUTED BY (target_schema_src_id,target_node_src_id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_smd0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_smd0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_smd - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_smd AS 
SELECT --связь между таблицой ПКАП и дата продуктом который TIB публикует
'SMD'::text AS src_cd,
lower(t2.pm_name)  AS src_node_src_id,
lower(p.pm_name) AS src_schema_src_id,
p.meta_product_name AS target_node_src_id,
p.pm_name AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
lower(p.pm_name)|| '||' || lower(t2.pm_name) AS src_node_id,
p.pm_name || '||' || p.meta_product_name AS target_node_id,
'SMD' AS tgt_node_type_cd,
COALESCE(n.node_type_cd::TEXT,t2.model_element_type_name::text) AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report p
JOIN  s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table t2 ON t2.stock_element_id_ent = p.stock_element_id OR t2.stock_element_id_sch = p.stock_element_id
LEFT JOIN dg_full.meta_node_ref_table n ON  n.node_src_id=lower(t2.pm_name) AND n.schema_src_id=lower(p.pm_name)
WHERE 1=1
 AND (p.data_product_uuid, p.eff_date_ts) in (SELECT pr.data_product_uuid, max(pr.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr group by 1)
 AND p."cluster" ='GP_GM1' 
 AND p.pm_name ILIKE '%tib%'
 AND p.conf_item_product = 'CI02533826'
 UNION all
 SELECT -- свзязи  дата продуктов СМД и  ESPD подписки
 src_cd::text,
src_node_src_id::text,
src_schema_src_id::text,
target_node_src_id::text,
target_schema_src_id::text,
edge_type_src_id::int4,
property_id::int4,
weight::NUMERIC(15,2),
order_by::int4,
is_active::bool,
edge_type_cd::text,
src_node_id::text,
target_node_id::text,
tgt_node_type_cd::text,
src_node_type_cd::text,
enable_dq::text 
FROM temp_smd0 
UNION ALL
 SELECT -- свзязи  потока(подписки SMD) и stg entity
 'SMD'::text AS src_cd,
t.target_node_src_id  AS src_node_src_id,
t.target_schema_src_id AS src_schema_src_id,
n.node_src_id AS target_node_src_id,
n.schema_src_id AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
t.target_schema_src_id|| '||' || t.target_node_src_id AS src_node_id,
n.schema_src_id || '||' || n.node_src_id AS target_node_id,
n.node_type_cd AS tgt_node_type_cd,
'Flow'::text AS src_node_type_cd,
'1'::TEXT AS enable_dq
 FROM temp_smd0 t
  JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND  t.target_node_src_id = n.node_src_id  -- наши подписки из CTL
DISTRIBUTED BY (target_schema_src_id,target_node_src_id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_smd;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_smd - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_tfs - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_tfs AS 
SELECT 
'CTL'::text AS src_cd,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.wf_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.wf_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.path_tfs -- мы кладем в папку tfs
       ELSE '-'
END AS src_node_src_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.category_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.category_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN 'TFS' -- мы кладем в папку tfs
       ELSE '-'
END AS src_schema_src_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.path_tfs   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.path_tfs   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.wf_nm -- мы кладем в папку tfs
       ELSE '-'
END AS target_node_src_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN 'TFS'   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN 'TFS'   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.category_nm -- мы кладем в папку tfs
       ELSE '-'
END AS target_schema_src_id,
5::int4 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Принадлежит'::TEXT AS edge_type_cd,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.category_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.category_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN 'TFS' -- мы кладем в папку tfs
       ELSE '-'
END || '||' || CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.wf_nm   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.wf_nm   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.path_tfs -- мы кладем в папку tfs
       ELSE '-'
END AS src_node_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN 'TFS'   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN 'TFS'   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.category_nm -- мы кладем в папку tfs
       ELSE '-'
END || '||' || CASE WHEN  path_tfs ILIKE '%/to/%' THEN tt.path_tfs   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN tt.path_tfs   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN tt.wf_nm -- мы кладем в папку tfs
       ELSE '-'
END AS target_node_id,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN 'TFS'   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN 'TFS'   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN 'Flow' -- мы кладем в папку tfs
       ELSE '-'
END AS tgt_node_type_cd,
CASE WHEN  path_tfs ILIKE '%/to/%' THEN 'Flow'   --   мы забираем из папки tfs 
       WHEN  path_tfs ILIKE '%Qlik%' THEN 'Flow'   --   мы забираем из папки tfs
       WHEN  path_tfs ILIKE '%/from/%' THEN 'TFS' -- мы кладем в папку tfs
       ELSE '-'
END AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM (
SELECT DISTINCT 
                w.id AS wf_id,
                cc.name_ AS category_nm,
                w.name_ AS wf_nm,
                --------------------
                max(CASE
                    WHEN cp.param::text IN ('file_path_source'::TEXT, 'path_to_local'::TEXT, 'path_to_tfs'::TEXT, 'path_from_local'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS path_tfs
                -------------
             FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN temp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 
            AND w.deleted = false 
            AND (w.profile_id = ANY (ARRAY[329, 334])) 
            AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
          GROUP BY w.id, w.name_, cc.name_
) tt
WHERE tt.path_tfs IS NOT NULL
DISTRIBUTED BY (target_schema_src_id,target_node_src_id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_tfs;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_tfs - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


CREATE TEMPORARY TABLE temp_espd0 AS 
         SELECT 
            w.category_id,
            cc.name_ AS category_nm,
            w.profile_id,
            w.id AS wf_id,
            w.name_ AS wf_nm,
            max(
                CASE
                    WHEN cp.param::text = 'folderName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text) AS folder_nm,
            max(
                CASE
                    WHEN cp.param::text = 'workflowName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text) AS workflow_nm
           FROM  dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN temp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 AND w.deleted = false AND w.profile_id = 150
          GROUP BY w.category_id, cc.name_, w.profile_id, w.id, w.name_
         HAVING (max(
                CASE
                    WHEN cp.param::text = 'folderName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text) || max(
                CASE
                    WHEN cp.param::text = 'workflowName'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text)) IS NOT NULL
            DISTRIBUTED BY (wf_nm)    
;
RAISE NOTICE 'temp_espd0';

-- Связь ЕСПД объектов со списком загружаемых stg таблиц 
CREATE TEMPORARY TABLE temp_espd AS 
         SELECT 
            e1.category_id,
            e1.category_nm,
            e1.profile_id,
            e1.wf_id,
            e1.wf_nm,
            e1.folder_nm,
            e1.workflow_nm,
            mel.edge_id,
            current_timestamp AS load_dttm,
            mel.src_cd,
            -1::int4 AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            mel.src_node_src_id,
            mel.src_schema_src_id,
            mel.target_node_src_id,
            mel.target_schema_src_id,
            mel.edge_type_src_id,
            mel.weight,
            mel.order_by,
            mel.is_active
           FROM temp_espd0 e1
           LEFT JOIN s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link mel ON e1.wf_nm::text = mel.src_node_src_id::TEXT -- замена на АС СПОД (Ввод данных)
          WHERE 1=1
            AND mel.src_node_src_id::text ~~ 'ESPD%'::TEXT
            AND mel.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link h1)
            DISTRIBUTED BY (target_schema_src_id,target_node_src_id)    
        ;
RAISE NOTICE 'temp_espd';

CREATE TEMPORARY TABLE temp_wf0 AS 
WITH wf AS (
SELECT 
w.category_id,
w.profile_id,
w.id,
w.name_
FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
WHERE 1 = 1 
AND w.deleted = false 
AND (w.profile_id = ANY (ARRAY[329, 334, 74])) 
            AND (w.id IN ( SELECT cp1.wf_id
                  FROM dg_full.vctl_param cp1 
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- !! '%TIBDS%'::TEXT
                  GROUP BY cp1.wf_id))
)
         SELECT 
            w.category_id,
            cc.name_ AS category_nm,
            w.profile_id,
            w.id AS wf_id,
            w.name_ AS wf_nm,
            cp.param,
            cp.prior_value,
                CASE
                    WHEN cp.param::text in ('tgt_entity_id'::TEXT,'entity_id'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS tgt_entity_id,
                CASE
                    WHEN cp.param::text IN ('stg_schema_name'::TEXT,'stg_schema'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_espd_schema_name,
                CASE
                    WHEN cp.param::text IN ('stg_table_name'::TEXT,'object_name'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_espd_table_name,
                -------------
                CASE
                    WHEN cp.param::text IN ('hive_schema_name'::TEXT,'hive_schema_name_act'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_schema_name,
                CASE
                    WHEN cp.param::text IN ('hive_table_name'::TEXT, 'hive_table_name_act'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_table_name,
                ------
                CASE
                    WHEN cp.param::text = 'hive_schema_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_snp_schema_name,
                CASE
                    WHEN cp.param::text = 'hive_table_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_snp_table_name,
                -------------
                CASE
                    WHEN cp.param::text = 'hive_schema_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_diff_schema_name,
                CASE
                    WHEN cp.param::text = 'hive_table_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS src_hdp_diff_table_name,
                -------------
                CASE
                    WHEN cp.param::text in ('function_schema','ods_schema_name'::TEXT,'ods_schema'::TEXT, 'mart_schema_name'::TEXT ) THEN cp.prior_value -- + 
                    ELSE NULL::character varying
                END::text AS tgt_schema_name,
                CASE
                    WHEN cp.param::text in ('function_name','ods_table_name'::TEXT,'object_name'::TEXT, 'mart_table_name'::TEXT ) THEN cp.prior_value  -- + 
                    ELSE NULL::character varying
                END::text AS tgt_table_name,
                CASE WHEN cp.param::text in ('function_name') THEN 'Function'
                    WHEN cp.param::text in ('ods_table_name'::TEXT,'object_name'::text) THEN 'Table'
                    ELSE NULL::character varying
                END::text AS tgt_node_type_cd,
                CASE
                    WHEN cp.param::text = 'enable_dq'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS enable_dq,
                CASE
                    WHEN cp.param::text = 'column_key_list'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS column_key_list,
                CASE
                    WHEN cp.param::text = 'rin'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END::text AS column_rin,
                substring(CASE
                            WHEN cp.param::text = 'rin'::text THEN cp.prior_value
                            ELSE NULL::character varying
                            END::text, ']_(.*?)_POSTGRESQL') AS scenario_cd 
           FROM wf w 
             JOIN temp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp  
               ON w.id = cp.wf_id
          WHERE 1 = 1 
DISTRIBUTED BY (wf_nm);
RAISE NOTICE 'temp_wf0';

CREATE TEMPORARY TABLE temp_wf1 AS 
         SELECT w1.category_id,
            w1.category_nm,
            w1.profile_id,
            w1.wf_id,
            w1.wf_nm,
            max(w1.tgt_entity_id) AS tgt_entity_id,
            max(w1.src_espd_schema_name) AS src_espd_schema_name,
            max(w1.src_espd_table_name) AS src_espd_table_name,
            max(w1.src_hdp_schema_name) AS src_hdp_schema_name,
            max(w1.src_hdp_table_name) AS src_hdp_table_name,
            max(w1.src_hdp_snp_schema_name) AS src_hdp_snp_schema_name,
            max(w1.src_hdp_snp_table_name) AS src_hdp_snp_table_name,
            max(w1.src_hdp_diff_schema_name) AS src_hdp_diff_schema_name,
            max(w1.src_hdp_diff_table_name) AS src_hdp_diff_table_name,
            max(w1.tgt_schema_name) AS tgt_schema_name,
            max(w1.tgt_table_name) AS tgt_table_name,
            max(w1.tgt_node_type_cd) AS tgt_node_type_cd,
            max(w1.enable_dq) AS enable_dq,
            max(w1.column_key_list) AS column_key_list,
            max(w1.scenario_cd) AS scenario_cd
           FROM temp_wf0 w1
          GROUP BY w1.category_id, w1.category_nm, w1.profile_id, w1.wf_id, w1.wf_nm
/*         HAVING (((((((((max(w1.tgt_entity_id) || 
                       max(w1.src_espd_schema_name)) || 
                       max(w1.src_espd_table_name)) || 
                       max(w1.src_hdp_schema_name)) || 
                       max(w1.src_hdp_table_name)) || 
                       max(w1.src_hdp_snp_schema_name)) || 
                       max(w1.src_hdp_snp_table_name)) || 
                       max(w1.src_hdp_diff_schema_name)) || 
                       max(w1.src_hdp_diff_table_name)) || 
                       max(w1.tgt_schema_name)) || 
                       max(w1.tgt_table_name)) || 
                       max(w1.enable_dq)) IS NOT NULL*/
        DISTRIBUTED BY (src_espd_schema_name,src_espd_table_name);
RAISE NOTICE 'temp_wf1';        

CREATE TEMPORARY TABLE temp_simil AS 
SELECT 
tt.scenariocd AS  scenario_cd,
n.schema_src_id, 
n.node_src_id
FROM
(SELECT * FROM s_grnplm_as_cib_gm_meta_tib.etl_bk9scn
WHERE description = 'RUN FUNCTION'
UNION 
SELECT * FROM s_grnplm_as_cib_gm_meta.etl_bk9scn
WHERE description = 'RUN FUNCTION'
) tt
CROSS JOIN dg_full.meta_node_ref_table n 
WHERE 1=1
AND similarity( tt.sql_line , n.schema_src_id::Text || '||'::TEXT || n.node_src_id) >= 0.5
DISTRIBUTED BY (scenario_cd);
RAISE NOTICE 'temp_simil';        

CREATE TEMPORARY TABLE temp_wf AS 
         SELECT 
            w2.category_id,
            w2.category_nm,
            w2.profile_id,
            w2.wf_id,
            w2.wf_nm,
            w2.tgt_entity_id,
            w2.src_espd_schema_name,
            w2.src_espd_table_name,
            w2.src_hdp_schema_name,
            w2.src_hdp_table_name,
            w2.src_hdp_snp_schema_name,
            w2.src_hdp_snp_table_name,
            w2.src_hdp_diff_schema_name,
            w2.src_hdp_diff_table_name,
            COALESCE(w2.tgt_schema_name,s.schema_src_id) AS tgt_schema_name,
            COALESCE(w2.tgt_table_name, s.node_src_id ) AS tgt_table_name,
            COALESCE(w2.tgt_node_type_cd,'Function') AS tgt_node_type_cd,
            w2.enable_dq,
            w2.column_key_list,
            w2.scenario_cd
           FROM temp_wf1 w2
LEFT JOIN temp_simil s ON s.scenario_cd = w2.scenario_cd
        DISTRIBUTED BY (src_espd_schema_name,src_espd_table_name);
RAISE NOTICE 'temp_wf';        



CREATE TEMPORARY TABLE temp_final AS 
         SELECT DISTINCT 
            te.wf_id,
            es.category_nm AS espd_src_schema_src_id,
            es.wf_nm AS espd_src_node_src_id,
            es.target_node_src_id AS espd_target_node_src_id,
            es.target_schema_src_id AS espd_target_schema_src_id,
            --
            te.src_espd_schema_name AS wf_src_schema_src_id,
            te.src_espd_table_name AS wf_src_node_src_id,
            --
            te.src_hdp_schema_name AS wf_src_h_schema_src_id,
            te.src_hdp_table_name AS wf_src_h_node_src_id,
            --
            te.src_hdp_snp_schema_name AS wf_src_hs_schema_src_id,
            te.src_hdp_snp_table_name AS wf_src_hs_node_src_id,
            --
            te.src_hdp_diff_schema_name AS wf_src_hd_schema_src_id,
            te.src_hdp_diff_table_name AS wf_src_hd_node_src_id,
            --
            te.category_nm AS wf_target_schema_src_id,
            te.wf_nm AS wf_target_node_src_id,
            te.category_nm AS wf1_src_schema_src_id,
            te.wf_nm AS wf1_src_node_src_id,
            CASE WHEN POSITION('/' IN reverse(e."path")) <> 0 AND POSITION(e.name_::TEXT IN e."path") <> 0 
                 THEN substring(e."path" FROM 1 FOR (length(e."path") - POSITION('/' IN reverse(e."path")) + 1 ) - 1) 
                 ELSE DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e.name_ , 'xx'::TEXT, e."path" ) END AS wf1_target_schema_src_id,
            e.name_ AS wf1_target_node_src_id,
            -- DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path") AS wf2_src_schema_src_id,
            -- e.name_ AS wf2_src_node_src_id, -- entity -> table
            te.category_nm AS wf2_src_schema_src_id,
            te.wf_nm       AS wf2_src_node_src_id, -- change chain wf -> table
            te.tgt_schema_name AS wf2_target_schema_src_id,
            te.tgt_table_name AS wf2_target_node_src_id,
            te.tgt_node_type_cd AS wf2_tgt_node_type_cd,
            te.enable_dq,
            te.column_key_list
           FROM temp_wf te
             LEFT JOIN temp_espd es ON es.target_schema_src_id::text = te.src_espd_schema_name AND es.target_node_src_id::text = te.src_espd_table_name
             LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity e ON te.tgt_entity_id = e.id::TEXT
        DISTRIBUTED BY (wf_src_schema_src_id, wf_src_node_src_id)
        ;
RAISE NOTICE 'temp_final';    

-- Entity (trigger) -> Wf
CREATE TEMPORARY TABLE temp_wf01 AS 
WITH wf AS (
SELECT 
w.category_id,
w.profile_id,
w.id,
w.name_
FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
WHERE 1 = 1 
AND w.deleted = false 
AND (w.profile_id = ANY (ARRAY[329, 334, 74])) 
            AND (w.id IN ( SELECT cp1.wf_id
                  FROM dg_full.vctl_param cp1 
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
)
SELECT 
w.category_id,
cc.name_ AS wf_target_schema_src_id,
w.profile_id,
w.id AS wf_id,
w.name_ AS wf_target_node_src_id,
e.entity_id , e.stat_id , e.stat_type ,
CASE WHEN POSITION('/' IN reverse(ee."path")) <> 0 AND POSITION(ee.name_::TEXT IN ee."path") <> 0 
                 THEN substring(ee."path" FROM 1 FOR (length(ee."path") - POSITION('/' IN reverse(ee."path")) + 1 ) - 1) 
                 ELSE DECODE(ee."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, ee.name_ , 'xx'::TEXT, ee."path" ) 
END AS entity_src_schema_src_id,
ee.name_ AS entity_src_node_src_id
FROM wf w 
JOIN temp_meta_sg_category cc 
  ON w.category_id = cc.id
JOIN dg_full.vctl_wf_event_sched e ON e.wf_id = w.id::int8::TEXT
JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity ee ON e.entity_id = ee.id::int8::TEXT 
WHERE 1 = 1 
DISTRIBUTED BY (wf_target_schema_src_id, wf_target_node_src_id);
RAISE NOTICE 'temp_wf01';

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_edge_ctl_link - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_edge_ctl_link AS     
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.espd_src_schema_src_id::text AS src_schema_src_id,
    f.espd_src_node_src_id::text AS src_node_src_id,
    f.espd_target_schema_src_id::text AS target_schema_src_id,
    f.espd_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.espd_src_schema_src_id::text || '||'::text) || f.espd_src_node_src_id::text AS src_node_id,
    (f.espd_target_schema_src_id::text || '||'::text) || f.espd_target_node_src_id::text AS target_node_id,
    'Table'::text AS tgt_node_type_cd,
    'Flow'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.espd_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.espd_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.espd_target_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.espd_target_schema_src_id::TEXT,'') <> ''
  GROUP BY 
    f.wf_id,
    f.espd_src_schema_src_id::text ,
    f.espd_src_node_src_id::text ,
    f.espd_target_schema_src_id::text,
    f.espd_target_node_src_id::text ,
    (f.espd_src_schema_src_id || '||'::text) || f.espd_src_node_src_id::text ,
    (f.espd_target_schema_src_id::text || '||'::text) || f.espd_target_node_src_id::TEXT,
     f.enable_dq,
    f.column_key_list
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_schema_src_id::text AS src_schema_src_id,
    f.wf_src_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_schema_src_id || '||'::text) || f.wf_src_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
     f.wf_id,
     f.wf_src_schema_src_id::text, 
     f.wf_src_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_schema_src_id::text || '||'::text) || f.wf_src_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::TEXT,
     f.enable_dq,
    f.column_key_list
-------------------------
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_h_schema_src_id::text AS src_schema_src_id,
    f.wf_src_h_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_h_schema_src_id || '||'::text) || f.wf_src_h_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_h_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_h_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
     f.wf_src_h_schema_src_id::text, 
     f.wf_src_h_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_h_schema_src_id::text || '||'::text) || f.wf_src_h_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
---------------------------     
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_hs_schema_src_id::text AS src_schema_src_id,
    f.wf_src_hs_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_hs_schema_src_id || '||'::text) || f.wf_src_hs_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_hs_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_hs_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
     f.wf_src_hs_schema_src_id::text, 
     f.wf_src_hs_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_hs_schema_src_id::text || '||'::text) || f.wf_src_hs_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
---------------------------     
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf_src_hd_schema_src_id::text AS src_schema_src_id,
    f.wf_src_hd_node_src_id::text AS src_node_src_id,
    f.wf_target_schema_src_id::text AS target_schema_src_id,
    f.wf_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf_src_hd_schema_src_id || '||'::text) || f.wf_src_hd_node_src_id AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id::text AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Table'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf_src_hd_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_src_hd_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
     f.wf_src_hd_schema_src_id::text, 
     f.wf_src_hd_node_src_id::text, 
     f.wf_target_schema_src_id::text, 
     f.wf_target_node_src_id::text, 
     (f.wf_src_hd_schema_src_id::text || '||'::text) || f.wf_src_hd_node_src_id::text, (f.wf_target_schema_src_id::text || '||'::text) || f.wf_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
---------------------------     
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf1_src_schema_src_id::text AS src_schema_src_id,
    f.wf1_src_node_src_id::text AS src_node_src_id,
    f.wf1_target_schema_src_id::text AS target_schema_src_id,
    f.wf1_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf1_src_schema_src_id::text || '||'::text) || f.wf1_src_node_src_id::text AS src_node_id,
    (f.wf1_target_schema_src_id::text || '||'::text) || f.wf1_target_node_src_id::text AS target_node_id,
    'Entity'::text AS tgt_node_type_cd,
    'Flow'::text AS src_node_type_cd,
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf1_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf1_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf1_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf1_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
      f.wf1_src_schema_src_id::text, 
      f.wf1_src_node_src_id::text, 
      f.wf1_target_schema_src_id::text, 
      f.wf1_target_node_src_id::text, 
      (f.wf1_src_schema_src_id::text || '||'::text) || f.wf1_src_node_src_id::text, (f.wf1_target_schema_src_id::text || '||'::text) || f.wf1_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list
UNION
 SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.wf2_src_schema_src_id::text AS src_schema_src_id,
    f.wf2_src_node_src_id::text AS src_node_src_id,
    f.wf2_target_schema_src_id::text AS target_schema_src_id,
    f.wf2_target_node_src_id::text AS target_node_src_id,
    1 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Принадлежит'::text AS edge_type_cd,
    (f.wf2_src_schema_src_id::text || '||'::text) || f.wf2_src_node_src_id::text AS src_node_id,
    (f.wf2_target_schema_src_id || '||'::text) || f.wf2_target_node_src_id AS target_node_id,
    f.wf2_tgt_node_type_cd AS tgt_node_type_cd,
    'Flow'::text AS src_node_type_cd, -- 'Entity' - change chain Wf -> Table
    f.enable_dq ,
    f.column_key_list
   FROM temp_final f
  WHERE 1 = 1 
    AND COALESCE(f.wf2_src_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf2_src_node_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf2_target_schema_src_id::TEXT,'') <> ''
    AND COALESCE(f.wf2_target_node_src_id::TEXT,'') <> ''
  GROUP BY 
  f.wf_id,
    f.wf2_src_schema_src_id::text, 
    f.wf2_src_node_src_id::text, 
    f.wf2_target_schema_src_id::text, 
    f.wf2_target_node_src_id::text, 
    (f.wf2_src_schema_src_id::text || '||'::text) || f.wf2_src_node_src_id::text, (f.wf2_target_schema_src_id::text || '||'::text) || f.wf2_target_node_src_id::text,
     f.enable_dq,
    f.column_key_list,
     f.wf2_tgt_node_type_cd
UNION      
SELECT 
    f.wf_id::bigint AS edge_id,
    now() AS load_dttm,
    'CTL'::text AS src_cd, --'GP'
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    f.entity_src_schema_src_id::text AS src_schema_src_id,
    f.entity_src_node_src_id::text   AS src_node_src_id,
    f.wf_target_schema_src_id::text  AS target_schema_src_id,
    f.wf_target_node_src_id::text    AS target_node_src_id,
    7 AS edge_type_src_id,
    1 AS weight,
    1 AS order_by,
    true AS is_active,
    'Влияет на запуск'::text AS edge_type_cd,
    (f.entity_src_schema_src_id::text || '||'::text) || f.entity_src_node_src_id::text AS src_node_id,
    (f.wf_target_schema_src_id || '||'::text) || f.wf_target_node_src_id AS target_node_id,
    'Flow'::text AS tgt_node_type_cd,
    'Entity'::text AS src_node_type_cd,
    NULL::text AS enable_dq ,
    NULL::text AS column_key_list
FROM temp_wf01 f
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_edge_ctl_link;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_edge_ctl_link - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_edge_qs_link - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_edge_qs_link AS 
WITH tt_main AS (
SELECT 
tt.*
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  ELSE substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  END  AS schema_src_id
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  ELSE substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  END AS node_src_id
, CASE WHEN  tt.lng_object_type = 'TXT' THEN 8
       WHEN  tt.lng_object_type = 'EXCEL' THEN 8
       WHEN  tt.lng_object_type = 'SQL' THEN 1
       WHEN  tt.lng_object_type = 'QVD' THEN 6
       WHEN  tt.lng_object_type = 'CSV' THEN 8
       WHEN  tt.lng_object_type = 'APP' THEN 13
  END AS  node_type_src_id
, CASE WHEN  tt.lng_object_type = 'TXT' THEN 'Excel\CSV'
       WHEN  tt.lng_object_type = 'EXCEL' THEN 'Excel\CSV'
       WHEN  tt.lng_object_type = 'SQL' THEN 'Table'
       WHEN  tt.lng_object_type = 'QVD' THEN 'QVD'
       WHEN  tt.lng_object_type = 'CSV' THEN 'Excel\CSV'
       WHEN  tt.lng_object_type = 'APP' THEN'Application QS'
  END AS  node_type_cd
FROM (
SELECT DISTINCT  
l.app_key, l.lng_flow , COALESCE(l.lng_src_flag,'-') AS lng_src_flag, l.lng_object_type , l.lng_application
, CASE 
  WHEN POSITION ('_20' IN l.lng_object) <> 0  THEN regexp_replace(REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://'),'\_20.*?\.','.')
  ELSE REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://') END AS lng_object_1
FROM s_grnplm_as_cib_gm_ods_qlik.lineage l 
WHERE 1=1
AND lng_object NOT LIKE '%ArchivedLogsFolder%'
AND lng_object NOT LIKE '%ServerLogFolder%'
AND lng_object NOT LIKE '%/Meta/AppSrc/%'
AND l.lng_application NOT LIKE '%Find Applications SQL Sources%'
) tt
)
, tt_edge AS (
SELECT 
'QS' AS src_cd,
t1.node_src_id AS src_node_src_id,
t1.schema_src_id AS src_schema_src_id,
t1.lng_application AS target_node_src_id,
t1.lng_flow AS target_schema_src_id,
2 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Входит в'::TEXT AS edge_type_cd,
t1.schema_src_id || '||' || t1.node_src_id AS src_node_id,
t1.lng_flow || '||' || t1.lng_application AS target_node_id,
'Application QS'::text AS tgt_node_type_cd,
t1.node_type_cd AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM tt_main t1
WHERE lng_src_flag = '1' -- приложение - потребитель
UNION 
SELECT 
'QS' AS src_cd,
t2.lng_application AS src_node_src_id,
t2.lng_flow AS src_schema_src_id,
t2.node_src_id AS target_node_src_id,
t2.schema_src_id AS target_schema_src_id,
5 AS edge_type_src_id,
NULL::int4 AS property_id,
1::NUMERIC(15,2) AS weight,
1::int4 AS order_by,
TRUE::bool AS is_active,
'Результат'::TEXT AS edge_type_cd,
t2.lng_flow || '||' || t2.lng_application AS src_node_id,
t2.schema_src_id || '||' || t2.node_src_id AS target_node_id,
t2.node_type_cd AS tgt_node_type_cd,
'Application QS'::text AS src_node_type_cd,
'1'::TEXT AS enable_dq 
FROM tt_main t2
WHERE lng_src_flag = '-' -- приложение - источник
)
SELECT 
e.src_cd,
e.src_node_src_id,
e.src_schema_src_id,
e.target_node_src_id,
e.target_schema_src_id,
e.edge_type_src_id,
e.property_id,
e.weight,
e.order_by,
e.is_active,
e.edge_type_cd,
e.src_node_id,
e.target_node_id,
e.tgt_node_type_cd,
e.src_node_type_cd,
e.enable_dq 
FROM tt_edge e
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_edge_qs_link;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_edge_qs_link - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


CREATE TEMPORARY TABLE temp_p AS 
         SELECT 
            (pgn.nspname::text || '||'::text) || pgp.proname::text AS target_node_id,
            pgn.nspname,
            replace(pgp.proname::text, '"'::text, ''::text) AS proname,
            replace(regexp_replace(btrim(pgp.prosrc), '[\n\r\t\v]+'::text, ''::text), '"'::text, ''::text) AS prosrc
           FROM pg_proc pgp
             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s1 ON pgn.nspname::text = s1.schema_src_id::text
          WHERE 1 = 1
        DISTRIBUTED BY (nspname);
RAISE NOTICE 'temp_p';

CREATE TEMPORARY TABLE temp_tt AS 
         SELECT 
            t.schema_src_id,
            replace(t.node_src_id::text, '"'::text, ''::text) AS node_src_id,
            p.nspname,
            replace(p.proname, '"'::text, ''::text) AS proname,
            p.prosrc,
                CASE
                    WHEN lower(p.prosrc) like ((('%insert into '::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::TEXT || '%') THEN 5
                    ELSE NULL::integer
                END AS ww5,
                CASE
                    WHEN lower(p.prosrc) like (('%v_tgt_table_name text default '''::text || t.node_src_id::text) || ''';%'::text)
                     AND lower(p.prosrc) like (('%v_tgt_schema_name text default '''::text || t.schema_src_id::text) || ''';%'::text) THEN 5
                    ELSE NULL::integer
                END AS ww51,
                CASE
                    WHEN lower(p.prosrc) like (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || '%'::text) 
                      OR lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || ' %'::text) 
                      OR lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || '(%'::text) THEN 4
                    ELSE NULL::integer
                END AS ww4,
            t.is_active,
            t.node_type_cd AS src_node_type_cd,
            'Function'::text AS tgt_node_type_cd
           FROM dg_full.meta_node_ref_table t
             CROSS JOIN temp_p p
          WHERE 1 = 1 
            --- !!! AND t.src_cd = 'GP'::text 
            AND ((t.schema_src_id::text || '||'::text) || t.node_src_id::text) <> p.target_node_id
            AND COALESCE(t.schema_src_id::TEXT,'') <> '' 
            AND COALESCE(t.node_src_id::TEXT,'') <> ''
DISTRIBUTED BY (schema_src_id, node_src_id );
RAISE NOTICE 'temp_tt';

CREATE TEMPORARY TABLE temp_tt1 AS 
         SELECT
                CASE
                    WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || '(%'::text) THEN 6
                    WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || ' %'::text) THEN 8
                    WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || '%'::text) THEN 8
                    WHEN etl.sql_line::text ~~ ((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) THEN 8
                    ELSE NULL::integer
                END AS edge_type_src_id,
            replace(src.node_src_id::text, '"'::text, ''::text)::text AS src_node_src_id,
            src.schema_src_id::text AS src_schema_src_id,
            replace(tgt.node_src_id::text, '"'::text, ''::text)::text AS target_node_src_id,
            tgt.schema_src_id::text AS target_schema_src_id,
            src.is_active,
            tgt.node_type_cd AS tgt_node_type_cd,
            src.node_type_cd AS src_node_type_cd
           FROM (SELECT * FROM s_grnplm_as_cib_gm_meta.etl_bk9scn t1
                 UNION 
                 SELECT * FROM s_grnplm_as_cib_gm_meta_tib.etl_bk9scn t2
                ) etl
             JOIN dg_full.meta_node_ref_table tgt ON etl.scenariocd::text = replace(tgt.node_src_id::text, '_'::text, ''::text)
             CROSS JOIN dg_full.meta_node_ref_table src
          WHERE 1 = 1
DISTRIBUTED BY (src_node_src_id,src_schema_src_id,target_node_src_id,target_schema_src_id) ;
RAISE NOTICE 'temp_tt1';

/* Массив доп.свойств */
CREATE TEMPORARY TABLE tmp_pp AS
SELECT m.object_src_id,
       m.schema_src_id,
       m.property_type_src_id,
       m.property_val 
FROM dg_full.vmeta_property_hsat m
WHERE (m.load_dttm,m.object_src_id,m.schema_src_id, m.property_type_src_id) 
IN (SELECT 
       max(m0.load_dttm) AS max,
       m0.object_src_id,
       m0.schema_src_id,
       m0.property_type_src_id
    FROM dg_full.vmeta_property_hsat m0
    GROUP BY m0.object_src_id, m0.schema_src_id, m0.property_type_src_id)
DISTRIBUTED BY (schema_src_id, object_src_id, property_type_src_id)
;
RAISE NOTICE 'tmp_pp';


CREATE TEMPORARY TABLE temp_bb AS 
         SELECT DISTINCT
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            replace(ns_src.nspname::text, '"'::text, ''::text)::text AS src_schema_src_id,
            t.relname::text AS src_node_src_id,
            ns_tgt.nspname::text AS target_schema_src_id,
            replace(v.relname::text, '"'::text, ''::text)::text AS target_node_src_id,
            2 AS edge_type_src_id,
            1 AS weight,
            1 AS order_by,
            CASE
             WHEN coalesce(pp.property_val,'1') = '1'::text THEN TRUE
             WHEN coalesce(pp.property_val,'1') = '0'::text THEN FALSE
             ELSE FALSE
            END AS is_active,
                CASE
                    WHEN v.relkind = 'v'::"char" THEN 'View'::text
                    WHEN v.relkind = 'm'::"char" THEN 'View'::text
                    WHEN v.relkind = 'p'::"char" THEN 'Table'::text
                    WHEN v.relkind = 'r'::"char" THEN 'Table'::text
                    WHEN v.relkind = 't'::"char" THEN 'Table'::text
                    WHEN v.relkind = 'f'::"char" THEN 'Function'::text
                    ELSE v.relkind::text
                END AS tgt_node_type_cd,
                CASE
                    WHEN t.relkind = ANY (ARRAY['v'::"char", 'm'::"char"]) THEN 'View'::text
                    WHEN v.relkind = ANY (ARRAY['p'::"char", 'r'::"char", 't'::"char"]) THEN 'Table'::text
                    WHEN t.relkind = ANY (ARRAY['p'::"char", 'r'::"char", 't'::"char"]) THEN 'Table'::text
                    WHEN t.relkind = 'f'::"char" THEN 'Function'::text
                    ELSE t.relkind::text
                END AS src_node_type_cd
           FROM pg_depend d
             JOIN pg_rewrite r ON r.oid = d.objid
             JOIN pg_class v ON v.oid = r.ev_class
             JOIN pg_namespace ns_tgt ON ns_tgt.oid = v.relnamespace
             JOIN dg_full.meta_schema_ref_table s ON ns_tgt.nspname::text = s.schema_src_id::text
             JOIN pg_class t ON t.oid = d.refobjid
             JOIN pg_namespace ns_src ON ns_src.oid = t.relnamespace
             LEFT JOIN tmp_pp pp ON pp.object_src_id::text = t.relname::text AND pp.schema_src_id::text = ns_src.nspname::text AND pp.property_type_src_id = 6
          WHERE 1 = 1 
            AND (v.relkind = ANY (ARRAY['p'::"char", 't'::"char", 'r'::"char", 'v'::"char", 'm'::"char", 'f'::"char"])) 
            AND d.classid = 'pg_rewrite'::regclass::oid 
            AND (d.refclassid = 'pg_class'::regclass::oid OR d.refclassid = 'pg_proc'::regclass::oid) AND NOT v.oid = d.refobjid AND ns_src.nspname::text <> 'pg_catalog'::text AND ns_tgt.nspname::text <> 'pg_catalog'::text
        UNION ALL
         SELECT DISTINCT
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.nspname
                    ELSE tt.schema_src_id
                END::text AS src_schema_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.proname
                    ELSE tt.node_src_id
                END::text AS src_node_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.schema_src_id
                    ELSE tt.nspname
                END::text AS target_schema_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.node_src_id
                    ELSE tt.proname
                END::text AS target_node_src_id,
            COALESCE(tt.ww5, tt.ww51, tt.ww4) AS edge_type_src_id,
            1 AS weight,
            1 AS order_by,
            tt.is_active,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.src_node_type_cd::text
                    ELSE tt.tgt_node_type_cd
                END AS tgt_node_type_cd,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.tgt_node_type_cd::character varying
                    ELSE tt.src_node_type_cd
                END AS src_node_type_cd
           FROM temp_tt tt
          WHERE 1 = 1 
          AND COALESCE(tt.ww4, tt.ww5, tt.ww51) IS NOT NULL 
          AND tt.nspname::text <> 'pg_catalog'::text 
          AND tt.schema_src_id::text <> 'pg_catalog'::text
        UNION ALL
         SELECT DISTINCT 
            current_timestamp AS load_dttm,
            d.src_cd,
            -1::integer AS wf_load_id,
            d.src_schema_src_id::text,
            replace(d.src_node_src_id::text, '"'::text, ''::text)::text AS src_node_src_id,
            d.target_schema_src_id::text,
            replace(d.target_node_src_id::text, '"'::text, ''::text)::text AS target_node_src_id,
            d.edge_type_src_id,
            d.weight::integer AS weight,
            d.order_by,
            d.is_active,
            ntt.node_type_cd::text AS tgt_node_type_cd,
            nts.node_type_cd::text AS src_node_type_cd
           FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link d -- замена на АС СПОД (Ввод данных)
             LEFT JOIN dg_full.meta_node_ref_table ns ON d.src_schema_src_id::text = ns.schema_src_id::text 
                                                                           AND d.src_node_src_id::text = ns.node_src_id::text
             LEFT JOIN dg_full.meta_node_type_ref_table nts ON ns.node_type_src_id = nts.node_type_src_id
             LEFT JOIN dg_full.meta_node_ref_table nt ON d.target_schema_src_id::text = nt.schema_src_id::text 
                                                                           AND d.target_node_src_id::text = nt.node_src_id::text
             LEFT JOIN dg_full.meta_node_type_ref_table ntt ON nt.node_type_src_id = ntt.node_type_src_id
           WHERE 1=1
             AND d.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link h1)
             AND d.src_cd::text IN ( 'QS','Navi','SMD')
        DISTRIBUTED BY (src_schema_src_id, src_node_src_id,target_schema_src_id, target_node_src_id);
RAISE NOTICE 'temp_bb';

-- dg_full.vmeta_edge_link source
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_edge_link - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_edge_link AS 
 SELECT DISTINCT 
    -1::bigint AS edge_id,
    bb.load_dttm,
    bb.src_cd,
    bb.wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    bb.src_schema_src_id::text AS src_schema_src_id,
    bb.src_node_src_id::text,
    bb.target_schema_src_id::text,
    bb.target_node_src_id::text AS target_node_src_id,
    bb.edge_type_src_id,
    bb.weight,
    bb.order_by,
        CASE
            WHEN bb.src_node_src_id ~~ '%save_step_to_logs%'::text OR bb.target_node_src_id ~~ '%save_step_to_logs%'::text THEN false
            ELSE bb.is_active
        END AS is_active,
    ee.edge_type_cd,
    (bb.src_schema_src_id || '||'::text) || bb.src_node_src_id::text AS src_node_id,
    (bb.target_schema_src_id::text || '||'::text) || bb.target_node_src_id::text AS target_node_id,
    bb.tgt_node_type_cd,
    bb.src_node_type_cd,
    NULL::TEXT AS enable_dq , 
    NULL::TEXT AS column_key_list
   FROM temp_bb bb
     JOIN dg_full.meta_edge_type_ref_table ee ON bb.edge_type_src_id = ee.edge_type_src_id
  GROUP BY bb.load_dttm, bb.src_cd, bb.wf_load_id,  
           bb.src_schema_src_id::text, bb.src_node_src_id::text, bb.target_schema_src_id::text, bb.target_node_src_id::text, bb.edge_type_src_id, bb.weight, bb.order_by,
        CASE
            WHEN bb.src_node_src_id ~~ '%save_step_to_logs%'::text OR bb.target_node_src_id ~~ '%save_step_to_logs%'::text THEN false
            ELSE bb.is_active
        END, ee.edge_type_cd, 
        (bb.src_schema_src_id || '||'::text) || bb.src_node_src_id::text, 
        (bb.target_schema_src_id::text || '||'::text) || bb.target_node_src_id, bb.tgt_node_type_cd, bb.src_node_type_cd
UNION ALL 
 SELECT 
    cc.edge_id,
    cc.load_dttm,
    cc.src_cd,
    cc.wf_load_id,
    cc.eff_from_dttm,
    cc.eff_to_dttm,
    cc.last_seen_dttm,
    cc.src_schema_src_id::text,
    cc.src_node_src_id::text,
    cc.target_schema_src_id::text,
    cc.target_node_src_id::text,
    cc.edge_type_src_id,
    cc.weight,
    cc.order_by,
    cc.is_active,
    cc.edge_type_cd::character varying(100) AS edge_type_cd,
    cc.src_node_id::text,
    cc.target_node_id::text,
    cc.tgt_node_type_cd,
    cc.src_node_type_cd,
    cc.enable_dq , 
    cc.column_key_list
   FROM temp_meta_edge_ctl_link cc
UNION ALL 
 SELECT 
    -1::int8 AS edge_id,
    current_timestamp AS load_dttm,
    q.src_cd,
    -1::int8 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm,
    q.src_schema_src_id::text,
    q.src_node_src_id::text,
    q.target_schema_src_id::text,
    q.target_node_src_id::text,
    q.edge_type_src_id,
    q.weight,
    q.order_by,
    q.is_active,
    q.edge_type_cd::character varying(100) AS edge_type_cd,
    q.src_node_id::text,
    q.target_node_id::text,
    q.tgt_node_type_cd,
    q.src_node_type_cd,
    q.enable_dq ,
    NULL::TEXT AS column_key_list
   FROM temp_meta_edge_qs_link q
UNION   ALL    
SELECT 
    -1::int8 AS edge_id,
    current_timestamp AS load_dttm,
    s.src_cd, 
    - 1::int8 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm,
    s.src_schema_src_id,
    s.src_node_src_id,
    s.target_schema_src_id,
    s.target_node_src_id,
    s.edge_type_src_id,
    s.weight,
    s.order_by,
    s.is_active,
    s.edge_type_cd::character varying(100) AS edge_type_cd,
    s.src_node_id::text,
    s.target_node_id::text,
    s.tgt_node_type_cd,
    s.src_node_type_cd,
    s.enable_dq ,
    NULL::text AS column_key_list
FROM temp_smd s
UNION   ALL    
SELECT 
    -1::int8 AS edge_id,
    current_timestamp AS load_dttm,
    t.src_cd, 
    -1::int8 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm,
    t.src_schema_src_id,
    t.src_node_src_id,
    t.target_schema_src_id,
    t.target_node_src_id,
    t.edge_type_src_id,
    t.weight::integer,
    t.order_by,
    t.is_active,
    t.edge_type_cd::character varying(100) AS edge_type_cd,
    t.src_node_id::text,
    t.target_node_id::text,
    t.tgt_node_type_cd,
    t.src_node_type_cd,
    t.enable_dq ,
    NULL::text AS column_key_list
FROM temp_tfs t
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_edge_link;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_edge_link - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
   
DROP TABLE IF EXISTS temp_tt;
DROP TABLE IF EXISTS temp_tt1;
DROP TABLE IF EXISTS temp_bb;
DROP TABLE IF EXISTS temp_pp;
   
/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_edge_link';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_edge_link;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_edge_link'|| chr(9) || v_deleted_row::text;


/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_edge_link ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_edge_link 
(edge_id,
    load_dttm,
    src_cd,
    wf_load_id,
    eff_from_dttm,
    eff_to_dttm,
    last_seen_dttm,
    src_schema_src_id,
    src_node_src_id,
    target_schema_src_id,
    target_node_src_id,
    edge_type_src_id,
    weight,
    order_by,
    is_active,
    edge_type_cd,
    src_node_id,
    target_node_id,
    tgt_node_type_cd,
    src_node_type_cd,
    enable_dq ,
    column_key_list
    )
SELECT  
    l.edge_id,
    l.load_dttm,
    l.src_cd,
    l.wf_load_id,
    l.eff_from_dttm,
    l.eff_to_dttm,
    l.last_seen_dttm,
    l.src_schema_src_id,
    l.src_node_src_id,
    l.target_schema_src_id,
    l.target_node_src_id,
    l.edge_type_src_id,
    l.weight,
    l.order_by,
    l.is_active,
    l.edge_type_cd,
    l.src_node_id,
    l.target_node_id,
    l.tgt_node_type_cd,
    l.src_node_type_cd,
    l.enable_dq ,
    l.column_key_list
FROM temp_meta_edge_link l
--!! JOIN dg_full.meta_schema_ref_table ss ON l.src_schema_src_id = ss.schema_src_id
--!! JOIN dg_full.meta_schema_ref_table st ON l.target_schema_src_id = st.schema_src_id
;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_edge_link' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_edge_link - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_edge_qs_link;
DROP TABLE IF EXISTS temp_meta_edge_ctl_link;
DROP TABLE IF EXISTS temp_meta_edge_link;
DROP TABLE IF EXISTS temp_meta_sg_category;
DROP TABLE IF EXISTS temp_espd0;
DROP TABLE IF EXISTS temp_espd;
DROP TABLE IF EXISTS temp_wf0;
DROP TABLE IF EXISTS temp_wf1;
DROP TABLE IF EXISTS temp_wf;
DROP TABLE IF EXISTS temp_wf01;
DROP TABLE IF EXISTS temp_final;
DROP TABLE IF EXISTS temp_simil;
DROP TABLE IF EXISTS temp_p;
DROP TABLE IF EXISTS temp_pp;
DROP TABLE IF EXISTS temp_tfs;
DROP TABLE IF EXISTS temp_smd0;
DROP TABLE IF EXISTS temp_smd;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;








$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_error_event_stat(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
/*
 * Change Log
 * 2024-10-04 Create function
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_error_event_stat';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_error_event_stat';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

-- plan_   - дата+время плана
-- plan_dt - дата плана
-- время плана берем из среднего факта для триггерных событий   

 
CREATE TEMPORARY TABLE temp_stat0
AS
SELECT DISTINCT 
            m.schema_src_id,
            m.table_src_id,
            m.screen_id,
            m.metric,
            m.wf_load_id,
            m.record_identifier::jsonb ->> 'unit'::text AS unit,
            m.record_error,
            m.load_dttm
            FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact m
          WHERE 1 = 1 AND m.record_identifier::jsonb ?| ARRAY['unit'::text]
DISTRIBUTED BY (schema_src_id,table_src_id)
;
RAISE NOTICE 'temp_stat0';

CREATE TEMPORARY TABLE temp_stat1
AS
SELECT DISTINCT 
            m.schema_src_id,
            m.table_src_id,
            m.screen_id,
            m.metric,
            m.wf_load_id,
            m.unit,
            max(m.wf_load_id) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.unit) AS max_wf_load_id,
            count(*) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.unit) AS str_cnt,
            min(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.unit) AS min_rec_error,
            max(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.unit) AS max_rec_error,
            avg(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.unit) AS avg_rec_error,
            stddev(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.unit) AS stddev_rec_error,
            avg(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.unit ORDER BY m.load_dttm ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS avg_moving_rec_error
           FROM temp_stat0 m
DISTRIBUTED BY (schema_src_id,table_src_id)
;
RAISE NOTICE 'temp_stat1';
  
CREATE TEMPORARY TABLE temp_stat2
AS
SELECT tt1.schema_src_id,
    tt1.table_src_id,
    tt1.screen_id,
    tt1.unit,
    tt1.metric,
    tt1.avg_rec_error,
    tt1.stddev_rec_error,
    tt1.str_cnt,
    tt1.min_rec_error,
    tt1.max_rec_error,
    tt1.avg_moving_rec_error
   FROM temp_stat1 tt1
  WHERE 1 = 1 AND tt1.wf_load_id = tt1.max_wf_load_id
DISTRIBUTED BY (schema_src_id,table_src_id)
;
RAISE NOTICE 'temp_stat2';
  
/*Очистка 1*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_error_event_stat';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_error_event_stat;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_error_event_stat'|| chr(9) || v_deleted_row::text;

/*Добавление новых данных 1*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_error_event_stat ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_error_event_stat 
(
schema_src_id,
table_src_id,
screen_id,
unit, -- ADD 
metric,
avg_rec_error,
stddev_rec_error,
str_cnt,
min_rec_error,
max_rec_error,
avg_moving_rec_error ,
load_dttm
)
SELECT  
t.schema_src_id,
t.table_src_id,
t.screen_id,
t.unit , -- ADD 
t.metric,
t.avg_rec_error,
t.stddev_rec_error,
t.str_cnt,
t.min_rec_error,
t.max_rec_error,
t.avg_moving_rec_error ,
current_timestamp AS load_dttm
FROM temp_stat2 t;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_error_event_stat' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_error_event_stat - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_stat1;
DROP TABLE IF EXISTS temp_stat2;
---------------------------------

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;












$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_ld_update(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    

/*
 * Change Log
 * 2025-09-01 Заполнение таблиц
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT '';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_ld_update';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);



/*
CREATE TABLE IF NOT EXISTS dg_full.vmeta_ld_scheduler_plan_fact AS 
SELECT * 
FROM 
dg_full.vmeta_scheduler_plan_fact
DISTRIBUTED BY (schema_src_id, node_src_id, node_type_src_id);
*/

v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.vmeta_ld_scheduler_plan_fact;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact'|| chr(9) || v_deleted_row::text;

v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.vmeta_ld_scheduler_plan_fact
SELECT * 
FROM 
dg_full.vmeta_scheduler_plan_fact
;
GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'vmeta_ld_scheduler_plan_fact - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;
-----------------------------------------

/*
 CREATE TABLE IF NOT EXISTS dg_full.vmeta_ld_scheduler_fact AS 
SELECT * 
FROM 
dg_full.vmeta_scheduler_fact
DISTRIBUTED BY (sch_name, tbl_name, tbl_type);
*/

v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'vmeta_ld_scheduler_fact';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.vmeta_ld_scheduler_fact;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'vmeta_ld_scheduler_fact'|| chr(9) || v_deleted_row::text;

v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'vmeta_ld_scheduler_fact ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.vmeta_ld_scheduler_fact
SELECT * 
FROM 
dg_full.vmeta_scheduler_fact
;
GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'vmeta_ld_scheduler_fact' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'vmeta_ld_scheduler_fact - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;
-----------------------------------------------------
/*
CREATE TABLE IF NOT EXISTS dg_full.vmeta_ld_dq_statistic AS 
SELECT * 
FROM 
dg_full.vmeta_dq_statistic
DISTRIBUTED BY (schema_src_id);
*/

v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'vmeta_ld_dq_statistic';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.vmeta_ld_dq_statistic;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'vmeta_ld_dq_statistic'|| chr(9) || v_deleted_row::text;

v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'vmeta_ld_dq_statistic ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.vmeta_ld_dq_statistic
SELECT * 
FROM 
dg_full.vmeta_dq_statistic
;
GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'vmeta_ld_dq_statistic' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'vmeta_ld_dq_statistic - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;


v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;






$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_ld_update_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
    
    

/*
 * Change Log
 * 2025-09-01 Заполнение таблиц
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT '';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_ld_update';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);



/*
CREATE TABLE IF NOT EXISTS dg_full.vmeta_ld_scheduler_plan_fact AS 
SELECT * 
FROM 
dg_full.vmeta_scheduler_plan_fact
DISTRIBUTED BY (schema_src_id, node_src_id, node_type_src_id);
*/

v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.vmeta_ld_scheduler_plan_fact;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact'|| chr(9) || v_deleted_row::text;

v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.vmeta_ld_scheduler_plan_fact
SELECT * 
FROM 
dg_full.vmeta_scheduler_plan_fact
;
GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'vmeta_ld_scheduler_plan_fact' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'vmeta_ld_scheduler_plan_fact - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;
-----------------------------------------

/*
 CREATE TABLE IF NOT EXISTS dg_full.vmeta_ld_scheduler_fact AS 
SELECT * 
FROM 
dg_full.vmeta_scheduler_fact
DISTRIBUTED BY (sch_name, tbl_name, tbl_type);
*/

v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'vmeta_ld_scheduler_fact';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.vmeta_ld_scheduler_fact;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'vmeta_ld_scheduler_fact'|| chr(9) || v_deleted_row::text;

v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'vmeta_ld_scheduler_fact ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.vmeta_ld_scheduler_fact
SELECT * 
FROM 
dg_full.vmeta_scheduler_fact
;
GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'vmeta_ld_scheduler_fact' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'vmeta_ld_scheduler_fact - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;
-----------------------------------------------------
/*
CREATE TABLE IF NOT EXISTS dg_full.vmeta_ld_dq_statistic AS 
SELECT * 
FROM 
dg_full.vmeta_dq_statistic
DISTRIBUTED BY (schema_src_id);


v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'vmeta_ld_dq_statistic';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.vmeta_ld_dq_statistic_lg;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'vmeta_ld_dq_statistic'|| chr(9) || v_deleted_row::text;

v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'vmeta_ld_dq_statistic ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.vmeta_ld_dq_statistic_lg
SELECT * 
FROM 
dg_full.vmeta_dq_statistic_lg
;
GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'vmeta_ld_dq_statistic' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'vmeta_ld_dq_statistic - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;


v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);*/
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;










$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_node_ref_table(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-01-13 Entity's attributes change 
 * 2025-04-11 Add QS nodes
 * 2025-30-10 LGI add SMD nodes 
 * 2025-11-19 add tmp_TFS 
 * 2025-12-05 change node type TFS
 * 
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_node_ref_table';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_node_ref_table';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

ANALYZE dg_full.meta_schema_ref_table;
ANALYZE dg_full.meta_edge_link;
ANALYZE s_grnplm_as_cib_gm_ods_qlik.lineage;
ANALYZE s_grnplm_as_cib_gm_dg.meta_node_type_ref_table;
ANALYZE s_grnplm_as_cib_gm_ods_ctl.category;


CREATE TEMPORARY TABLE tmp_owner AS 
SELECT DISTINCT 
       s.src_node_id::TEXT AS node_id,
       s.src_node_src_id::TEXT,
       s.src_schema_src_id::TEXT
FROM dg_full.meta_edge_link s
WHERE ( s.src_node_type_cd = 'Table')
UNION
SELECT DISTINCT 
       t.target_node_id::TEXT AS node_id,
       t.target_node_src_id::TEXT,
       t.target_schema_src_id::TEXT 
FROM dg_full.meta_edge_link t
WHERE (t.tgt_node_type_cd = 'Table')
DISTRIBUTED BY (node_id) 
;
RAISE NOTICE 'tmp_owner';

-- список объектов GP
CREATE TEMPORARY TABLE tmp_gp_obj AS 
WITH tt AS (
SELECT 
            replace(pgc.relname::text, '"'::text, ''::text)::TEXT AS node_src_id,
            pgn.nspname::TEXT AS schema_src_id,
            pgc.relname AS node_cd,
            /* pgn.nspname::TEXT || '||'::Text || pgc.relname::TEXT */
            obj_description(pgc.oid) AS node_name,
                CASE
                    WHEN pgc.relkind = 't'::"char" THEN 1
                    WHEN pgc.relkind = 'r'::"char" THEN 1
                    WHEN pgc.relkind = 'p'::"char" THEN 1
                    WHEN pgc.relkind = 'v'::"char" THEN 2
                    WHEN pgc.relkind = 'm'::"char" THEN 3
                    ELSE NULL::integer
                END AS node_type_src_id,
            CASE WHEN  (pgn.nspname ||'||' || replace(pgc.relname::text, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_src_id::name
          WHERE 1 = 1 AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['t'::"char", 'r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        UNION
         SELECT 
            replace(pgp.proname::text, '"'::text, ''::text)::TEXT AS node_src_id,
            pgn.nspname::TEXT AS schema_src_id,
            pgp.proname AS node_cd,
            pgn.nspname::TEXT || '||'::Text || pgp.proname AS node_name,
            4 AS node_type_src_id,
            1 AS is_owner
           FROM pg_proc pgp
             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_src_id::name
          WHERE 1 = 1
)
SELECT 
            tt.node_src_id,
            tt.schema_src_id,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            tt.node_cd,
            /* pgn.nspname::TEXT || '||'::Text || pgc.relname::TEXT */
            tt.node_name,
            tt.node_type_src_id,
            n.node_type_cd,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            tt.is_owner
FROM tt
JOIN s_grnplm_as_cib_gm_dg.meta_node_type_ref_table n ON tt.node_type_src_id = n.node_type_src_id
DISTRIBUTED BY (schema_src_id, node_src_id)
;
RAISE NOTICE 'tmp_gp_obj';

-- список объектов QS
CREATE TEMPORARY TABLE tmp_qs_obj  AS 
WITH 
tmp_tt AS 
(
 SELECT DISTINCT  
 l.app_key, l.lng_flow , COALESCE(l.lng_src_flag,'-') AS lng_src_flag, l.lng_object_type , l.lng_application
 , CASE 
   WHEN POSITION ('_20' IN l.lng_object) <> 0  THEN regexp_replace(REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://'),'\_20.*?\.','.')
   ELSE REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://') END AS lng_object_1
 FROM s_grnplm_as_cib_gm_ods_qlik.lineage l 
 WHERE 1=1
  AND lng_object NOT LIKE '%ArchivedLogsFolder%'
  AND lng_object NOT LIKE '%ServerLogFolder%'
  AND lng_object NOT LIKE '%/Meta/AppSrc/%'
  AND l.lng_application NOT LIKE '%Find Applications SQL Sources%'
 )
, tmp_tt1 AS 
(
SELECT 
 tt.app_key, tt.lng_flow , tt.lng_src_flag, tt.lng_object_type , tt.lng_application, tt.lng_object_1
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  ELSE substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  END  AS schema_src_id
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  ELSE substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  END AS node_src_id
FROM tmp_tt tt
) 
, tt_main AS (
SELECT 
  tt1.schema_src_id
, tt1.node_src_id
, tt1.lng_application
, tt1.lng_flow
, tt1.app_key
, CASE WHEN  tt1.lng_object_type = 'TXT' THEN 8
       WHEN  tt1.lng_object_type = 'EXCEL' THEN 8
       WHEN  tt1.lng_object_type = 'SQL' THEN COALESCE(gp.node_type_src_id ,1)
       WHEN  tt1.lng_object_type = 'QVD' THEN 6
       WHEN  tt1.lng_object_type = 'CSV' THEN 8
       WHEN  tt1.lng_object_type = 'APP' THEN 13
  END AS  node_type_src_id
, CASE WHEN  tt1.lng_object_type = 'TXT' THEN 'Excel\CSV'
       WHEN  tt1.lng_object_type = 'EXCEL' THEN 'Excel\CSV'
       WHEN  tt1.lng_object_type = 'SQL' THEN COALESCE(gp.node_type_cd , 'Table')
       WHEN  tt1.lng_object_type = 'QVD' THEN 'QVD'
       WHEN  tt1.lng_object_type = 'CSV' THEN 'Excel\CSV'
       WHEN  tt1.lng_object_type = 'APP' THEN'Application QS'
  END AS  node_type_cd
FROM tmp_tt1 tt1
LEFT JOIN tmp_gp_obj gp ON gp.schema_src_id = tt1.schema_src_id
                       AND gp.node_src_id = tt1.node_src_id
)
, tt_node AS (
SELECT DISTINCT
t1.node_src_id AS node_src_id,
t1.schema_src_id AS schema_src_id,
'QS' AS src_cd,
t1.node_src_id AS node_cd,
t1.schema_src_id  || '||' || t1.node_src_id AS node_name,
t1.node_type_src_id AS node_type_src_id,
TRUE::bool AS is_active,
t1.node_type_cd AS node_type_cd
FROM tt_main t1
UNION 
SELECT DISTINCT
t2.lng_application AS node_src_id,
t2.lng_flow AS schema_src_id,
'QS' AS src_cd,
t2.app_key AS node_cd,
t2.lng_flow  || '||' || t2.lng_application AS node_name,
13::int4 AS node_type_src_id,
TRUE::bool AS is_active,
'Application QS'::text AS node_type_cd
FROM tt_main t2
)
SELECT 
n.node_src_id,
n.schema_src_id,
n.src_cd,
n.node_cd,
n.node_name,
n.node_type_src_id,
n.is_active,
n.node_type_cd
FROM tt_node n
WHERE NOT EXISTS (SELECT * FROM tmp_gp_obj o WHERE o.schema_src_id = n.schema_src_id AND o.node_src_id = n.node_src_id)
DISTRIBUTED BY (schema_src_id, node_src_id) 
;
RAISE NOTICE 'tmp_qs_obj';

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_meta_sg_category - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_meta_sg_category AS 
WITH RECURSIVE sg_category(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parentid   AS parent_id,
            g.name::text AS name_,
            1 AS depth,
            ARRAY[g.name::TEXT] AS path,
            false  AS cycle,
            g.name AS root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g -- s_grnplm_as_cib_gm_stg_espd.ctl_category g
          WHERE 1 = 1 
          AND g.parentid = 0 
          AND g.id in (1764,1964)  -- 1964 - ift
          AND g.deleted = FALSE
        UNION ALL
         SELECT g1.id,
            g1.parentid   AS parent_id,
            g1.name::TEXT AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name::TEXT,
            g1.name::TEXT = ANY (p.path),
            p.root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g1 --  s_grnplm_as_cib_gm_stg_espd.ctl_category g1
             JOIN sg_category p ON p.id = g1.parentid
          WHERE 1 = 1 AND NOT p.cycle
        )
 SELECT 
    sg_category.id,
    sg_category.parent_id,
    sg_category.name_,
    sg_category.depth,
    sg_category.path,
    sg_category.cycle,
    sg_category.root_name_id
   FROM sg_category
DISTRIBUTED BY (id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_meta_sg_category;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_meta_sg_category - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


-- список обьектов СМД поставщик и потребитель
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_smd - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_smd AS 
SELECT DISTINCT    -- Мы публикуем: dm -> продукт смд -> подписки потребитиелей
p.meta_product_name AS node_src_id,
lower( p.pm_name)  AS schema_src_id,
'SMD'::text AS src_cd,
p.data_product_name AS node_cd, 
lower(p.pm_name)  || '||' || p.meta_product_name AS node_name,
14::int4  AS node_type_src_id,
TRUE::bool AS is_active,
p.eff_date_ts::date AS  created_dt,
p.eff_date_ts::date AS  modified_dt,
'SMD' AS   node_type_cd,
1::int4 AS  is_owner
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report p 
WHERE 1=1
 AND (p.data_product_uuid, p.eff_date_ts) in (SELECT pr.data_product_uuid, max(pr.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr group by 1)
 AND p."cluster" ='GP_GM1' 
 AND p.pm_name ILIKE '%tib%'
 AND p.conf_item_product = 'CI02533826'
UNION
SELECT DISTINCT  -- Мы забираем: источник -> подписка смд -> stg -> ods -> dm 
lower(dt.pm_name) AS node_src_id,
lower(pr.pm_name)  AS schema_src_id,
'SMD'::text AS src_cd,
pr.data_product_name AS node_cd, 
lower(pr.pm_name) || '||' || lower(dt.pm_name) AS node_name,
1::int4  AS node_type_src_id,
TRUE::bool AS is_active,
pr.eff_date_ts::date AS  created_dt,
pr.eff_date_ts::date AS  modified_dt,
'SMD'::text AS   node_type_cd,
1::int4 AS  is_owner 
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_subscription_report s -- подписки
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_subscr_dp_rel r ON  s.subscription_uuid = r.subscription_uuid
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr  ON pr.stock_element_id = r.stock_element_id_sch
JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND s.subscription_uuid = n.node_src_id -- наши подписки из CTL
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table dt ON dt.stock_element_id_sch = pr.stock_element_id
WHERE 1=1
AND (pr.data_product_uuid, pr.eff_date_ts) in (SELECT pr1.data_product_uuid, max(pr1.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr1 group by 1)
AND s.subscription_status_display_name = 'Активна'
UNION
SELECT DISTINCT  --  связь таблиц с внешними продуктами
pr.meta_product_name AS node_src_id,
lower( pr.pm_name)  AS schema_src_id,
'SMD'::text AS src_cd,
pr.data_product_name AS node_cd, 
lower(pr.pm_name)  || '||' || pr.meta_product_name AS node_name,
14::int4  AS node_type_src_id,
TRUE::bool AS is_active,
pr.eff_date_ts::date AS  created_dt,
pr.eff_date_ts::date AS  modified_dt,
'SMD' AS   node_type_cd,
1::int4 AS  is_owner
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_subscription_report s -- подписки
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_subscr_dp_rel r ON  s.subscription_uuid = r.subscription_uuid
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr  ON pr.stock_element_id = r.stock_element_id_sch
JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND s.subscription_uuid = n.node_src_id -- наши подписки из CTL
--JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table dt ON dt.stock_element_id_sch = pr.stock_element_id
WHERE 1=1
AND (pr.data_product_uuid, pr.eff_date_ts) in (SELECT pr1.data_product_uuid, max(pr1.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr1 group by 1)
AND s.subscription_status_display_name = 'Активна'
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_smd;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_smd - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


-- список объектов Hadoop\Hive
CREATE TEMPORARY TABLE tmp_hdp AS 
          SELECT 
                w.id AS wf_id,
                w.name_ AS wf_nm,
                --------------------
                max(CASE
                    WHEN cp.param::text IN ('hive_schema_name'::TEXT,'hive_schema_name_act'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_schema_name,
                max(CASE
                    WHEN cp.param::text IN ('hive_table_name'::TEXT, 'hive_table_name_act'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_table_name,
                ------
                max(CASE
                    WHEN cp.param::text = 'hive_schema_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_snp_schema_name,
                max(CASE
                    WHEN cp.param::text = 'hive_table_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_snp_table_name,
                -------------
                max(CASE
                    WHEN cp.param::text = 'hive_schema_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_diff_schema_name,
                max(CASE
                    WHEN cp.param::text = 'hive_table_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_diff_table_name
                -------------
             FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN tmp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 
            AND w.deleted = false 
            AND (w.profile_id = ANY (ARRAY[329, 334])) 
            AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
          GROUP BY w.id, w.name_
  DISTRIBUTED BY (wf_id)       
;
RAISE NOTICE 'tmp_hdp';

-- список объектов TFS
CREATE TEMPORARY TABLE tmp_tfs AS 
          SELECT -- DISTINCT 
                max(w.id) AS wf_id,
                w.name_ AS wf_nm,
                --------------------
                max(CASE
                    WHEN cp.param::text IN ('file_path_source'::TEXT, 'path_to_local'::TEXT, 'path_to_tfs'::TEXT, 'path_from_local'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS path_tfs
                -------------
             FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN tmp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 
            AND w.deleted = false 
            AND (w.profile_id = ANY (ARRAY[329, 334])) 
            AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
          GROUP BY w.name_
  DISTRIBUTED BY (wf_id)       
;
RAISE NOTICE 'tmp_tfs';


CREATE TEMPORARY TABLE tmp_hdp_obj AS 
SELECT DISTINCT 
            h0.wf_id,
            h0.src_hdp_table_name::TEXT AS node_src_id ,
            h0.src_hdp_schema_name::TEXT  AS schema_src_id ,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            h0.src_hdp_table_name::TEXT AS node_cd,
            h0.src_hdp_schema_name::TEXT || '||'::Text || h0.src_hdp_table_name::TEXT AS node_name,
            1::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  (h0.src_hdp_schema_name::TEXT ||'||' || replace(h0.src_hdp_table_name::TEXT, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
FROM tmp_hdp h0 
WHERE h0.src_hdp_table_name IS NOT NULL AND h0.src_hdp_schema_name IS NOT NULL 
UNION 
SELECT DISTINCT 
            h1.wf_id,  
            h1.src_hdp_diff_table_name::TEXT AS node_src_id,
            h1.src_hdp_diff_schema_name::TEXT AS schema_src_id,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            h1.src_hdp_diff_table_name::TEXT AS node_cd,
            h1.src_hdp_diff_schema_name::TEXT || '||'::Text || h1.src_hdp_diff_table_name::TEXT AS node_name,
            1::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  (h1.src_hdp_diff_schema_name::TEXT ||'||' || replace(h1.src_hdp_diff_table_name::TEXT, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
FROM tmp_hdp h1 
WHERE h1.src_hdp_diff_table_name IS NOT NULL AND h1.src_hdp_diff_schema_name IS NOT NULL 
UNION 
SELECT DISTINCT 
            h2.wf_id,
            h2.src_hdp_snp_table_name::TEXT AS node_src_id,
            h2.src_hdp_snp_schema_name::TEXT AS schema_src_id,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            h2.src_hdp_snp_table_name::TEXT AS node_cd,
            h2.src_hdp_snp_schema_name::TEXT || '||'::Text || h2.src_hdp_snp_table_name::TEXT AS node_name,
            1::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  (h2.src_hdp_snp_schema_name::TEXT ||'||' || replace(h2.src_hdp_snp_table_name::TEXT, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
FROM tmp_hdp h2 
WHERE h2.src_hdp_snp_table_name IS NOT NULL AND h2.src_hdp_snp_schema_name IS NOT NULL 
DISTRIBUTED BY (schema_src_id, node_src_id)
;
RAISE NOTICE 'tmp_hdp_obj';


CREATE TEMPORARY TABLE tmp_bb AS
SELECT DISTINCT 
            t.wf_id,
            t.wf_nm::TEXT AS node_src_id,
            t.path_tfs::TEXT::TEXT AS schema_src_id,
            now() AS load_dttm,
            'CTL'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            t.wf_id::TEXT AS node_cd,
            t.path_tfs::TEXT || '||'::Text || t.wf_nm::TEXT AS node_name,
            17::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  ('TFS'::TEXT ||'||' || t.path_tfs) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner,
            'Folder'::text AS schema_type
FROM tmp_tfs t 
WHERE t.path_tfs IS NOT NULL 
UNION 
SELECT 
            h.wf_id,
            h.node_src_id::TEXT AS node_src_id,
            h.schema_src_id::TEXT AS schema_src_id,
            h.load_dttm,
            h.src_cd,
            h.wf_load_id,
            h.eff_from_dttm,
            h.eff_to_dttm,
            h.last_seen_dttm,
            h.node_cd,
            h.node_name,
            h.node_type_src_id,
            h.is_active,
            h.created_dt,
            h.modified_dt,
            h.is_owner,
            'Folder'::text AS schema_type
           FROM tmp_hdp_obj h
UNION
SELECT 
            '-1'::int8 AS wf_id,
            g.node_src_id::TEXT AS node_src_id,
            g.schema_src_id::TEXT AS schema_src_id,
            g.load_dttm,
            g.src_cd,
            g.wf_load_id,
            g.eff_from_dttm,
            g.eff_to_dttm,
            g.last_seen_dttm,
            g.node_cd,
            g.node_name,
            g.node_type_src_id,
            g.is_active,
            g.created_dt,
            g.modified_dt,
            g.is_owner,
            'Folder'::text AS schema_type
           FROM tmp_gp_obj g
         UNION
         SELECT
            '-1'::int8 AS wf_id,
            s.node_src_id,
            s.schema_src_id,
            current_timestamp AS load_dttm,
            s.src_cd,
            -1::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            current_timestamp AS last_seen_dttm,
            s.node_cd::text, 
            s.node_name,
            s.node_type_src_id,
            s.is_active,
            s.created_dt,
            s.modified_dt,
            s.is_owner,
            'Flow'::text AS schema_type
            FROM tmp_smd  s
            WHERE 1=1
        UNION
         SELECT 
            w.id AS wf_id,
            w.name_::TEXT AS node_src_id,
            cc.name_::TEXT AS schema_src_id,
            now() AS load_dttm,
            'CTL'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            w.name_::text AS node_cd,
            (cc.name_ || '||'::text) || w.name_::text AS node_name,
            5 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
                CASE
                    WHEN (w.id IN ( SELECT cp.wf_id
                       FROM dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_.ctl_param cp
                      WHERE cp.wf_id = w.id AND lower(cp.param::text) ~~ '%connectionlake%'::text AND cp.prior_value::text ~~ '%TIB%'::text)) THEN 1
                    ELSE 0
                END AS is_owner,
            'Cathegory'::text AS schema_type
           FROM tmp_meta_sg_category cc
           JOIN dg_full.vctl_wf w --  s_grnplm_as_cib_gm_stg_espd.ctl_wf w 
             ON cc.id = w.category_id
          WHERE 1 = 1 AND w.deleted = false AND (w.profile_id = ANY (ARRAY[150, 329, 334]))
                      AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
        UNION
         SELECT DISTINCT 
            e.id AS wf_id,
            e.name_::TEXT AS node_src_id,
            CASE WHEN POSITION('/' IN reverse(e."path")) <> 0 AND POSITION(e.name_::TEXT IN e."path") <> 0 
                 THEN substring(e."path" FROM 1 FOR (length(e."path") - POSITION('/' IN reverse(e."path")) + 1 ) - 1) 
                 ELSE DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e.name_ , 'xx'::TEXT, e."path" )
            END  AS schema_src_id, -- путь до entity
            now() AS load_dttm,
            'CTL'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            e.id::TEXT AS node_cd,
            DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path")::TEXT || '||'::Text || e.name_::TEXT AS node_name,
            10 AS node_type_src_id, -- Entity
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            1 AS is_owner,
            'Cathegory'::text AS schema_type
           FROM dg_full.vmeta_sg_entity ee_1
           JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity e 
             ON ee_1.id = e.id
          WHERE 1 = 1
          AND (e.id::int8::text IN (SELECT entity_id FROM dg_full.vctl_wf_event_sched)
           OR  e.id::int8::text IN (SELECT entity_id FROM dg_full.vctl_init_lock_check)
           OR  e.id::int8::text IN (SELECT entity_id FROM dg_full.vctl_init_lock_set)
          )
          GROUP BY e.id, 
                   e.name_::TEXT, 
                   e."path",
                   CASE WHEN POSITION('/' IN reverse(e."path")) <> 0 AND POSITION(e.name_::TEXT IN e."path") <> 0 
                 THEN substring(e."path" FROM 1 FOR (length(e."path") - POSITION('/' IN reverse(e."path")) + 1 ) - 1) 
                 ELSE DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e.name_ , 'xx'::TEXT, e."path" ) END
        UNION
         SELECT 
            '-1'::int8 AS wf_id,
            replace(m.node_src_id::text, '"'::text, ''::text)::TEXT AS node_src_id,
            m.schema_src_id::TEXT AS schema_src_id,
            current_timestamp AS load_dttm,
            m.src_cd,
            -1::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            current_timestamp AS last_seen_dttm,
            m.node_cd::TEXT,
            m.schema_src_id::TEXT || '||' || replace(m.node_src_id::text, '"'::text, ''::text)::TEXT AS node_name,
            m.node_type_src_id,
            m.is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            1 AS is_owner,
            ms.schema_type
         FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_node_ref_table m -- замена на АС СПОД (Ввод данных)
         LEFT JOIN dg_full.meta_schema_ref_table ms ON m.schema_src_id = ms.schema_src_id 
         WHERE 1=1
           AND m.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_node_ref_table h1)
           AND m.src_cd::text <> 'CTL'::TEXT
           -- !! AND m.src_cd::text <> 'SMD'::TEXT -- !! SMD убрать
           AND NOT EXISTS (SELECT * FROM tmp_gp_obj o WHERE o.node_src_id::text = m.node_src_id::text AND o.schema_src_id::text = m.schema_src_id::text)     
        UNION
         SELECT 
            '-1'::int8 AS wf_id,
            q.node_src_id,
            q.schema_src_id,
            current_timestamp AS load_dttm,
            q.src_cd,
            -1::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            current_timestamp AS last_seen_dttm,
            q.node_cd::TEXT,
            q.node_name,
            q.node_type_src_id,
            q.is_active,
            current_timestamp AS created_dt,
            current_timestamp AS modified_dt,
            1 AS is_owner,
            'Flow'::text AS schema_type
         FROM tmp_qs_obj q
         WHERE 1=1
DISTRIBUTED BY (schema_src_id, node_src_id)
;
RAISE NOTICE 'tmp_bb';

/* Массив доп.свойств */
CREATE TEMPORARY TABLE tmp_pp AS
SELECT m.object_src_id,
       m.schema_src_id,
       m.property_type_src_id,
       m.property_val 
FROM dg_full.vmeta_property_hsat m
WHERE (m.load_dttm,m.object_src_id,m.schema_src_id, m.property_type_src_id) 
IN (SELECT 
       max(m0.load_dttm) AS max,
       m0.object_src_id,
       m0.schema_src_id,
       m0.property_type_src_id
    FROM dg_full.vmeta_property_hsat m0
    GROUP BY m0.object_src_id, m0.schema_src_id, m0.property_type_src_id
  )
DISTRIBUTED BY (schema_src_id, object_src_id, property_type_src_id)
;
RAISE NOTICE 'tmp_pp';
      
INSERT INTO dg_full.meta_schema_ref_table 
(schema_src_id,schema_cd,descr,"type",schema_type,load_dttm,wf_load_id,src_cd)
WITH tab AS (
SELECT DISTINCT trim(REPLACE ( REPLACE ( regexp_matches  (description::text,'s_grnplm_as\S*?\s','g')::TEXT,'{"',''),'"}','')) AS  descr  
FROM s_grnplm_as_cib_ods_internal_jira_sigma.jiraissue
WHERE project = '258300' AND summary LIKE '%[PPM] Ввод РРМ GreenPlum%' 
AND description ILIKE '%TIBDS%'
)
SELECT 
DISTINCT 
b.schema_src_id::TEXT AS schema_src_id,
substring(b.schema_src_id,1,100)::TEXT AS schema_cd,
b.schema_src_id::TEXT AS descr,
'ПРОМ' AS "type",
b.schema_type AS schema_type,
current_timestamp AS load_dttm,
-1::int8  AS wf_load_id,
b.src_cd AS src_cd
FROM tmp_bb b
WHERE NOT EXISTS (SELECT schema_src_id FROM dg_full.meta_schema_ref_table t WHERE t.schema_src_id = b.schema_src_id::text)
AND b.schema_src_id IS NOT NULL
UNION 
SELECT 
jt.descr::TEXT AS schema_src_id,
substring(jt.descr::TEXT, 1, 100)::TEXT AS schema_cd,
jt.descr::TEXT AS descr,
'ПРОМ' AS "type",
'Schema'::TEXT AS schema_type,
current_timestamp AS load_dttm,
-1::int8  AS wf_load_id,
'GP'::TEXT AS src_cd
FROM (SELECT * FROM dg_full.meta_schema_ref_table m1
WHERE 1=1
AND m1.schema_type= 'Schema'
AND m1.schema_src_id NOT LIKE '%_ld_%'
) m
FULL JOIN  tab  jt ON m.schema_src_id::TEXT = jt.descr::text
WHERE 1=1
AND m.schema_src_id IS NULL 
;
RAISE NOTICE 'insert into meta_schema_ref_table';


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_node - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_node AS
SELECT 
    bb.wf_id,
    bb.node_src_id::TEXT AS node_src_id,
    bb.schema_src_id::TEXT AS schema_src_id,
    bb.load_dttm,
    bb.src_cd,
    bb.wf_load_id,
    bb.eff_from_dttm,
    bb.eff_to_dttm,
    bb.last_seen_dttm,
    bb.node_cd,
    bb.node_name,
    bb.node_type_src_id,
    CASE
     WHEN coalesce(pp.property_val,'1') = '1'::text THEN TRUE
     WHEN coalesce(pp.property_val,'1') = '0'::text THEN FALSE
     ELSE FALSE
    END AS is_active,
    bb.created_dt,
    bb.modified_dt,
    ee.node_type_cd,
    bb.is_owner
   FROM tmp_bb bb
   JOIN dg_full.meta_node_type_ref_table ee ON bb.node_type_src_id = ee.node_type_src_id
   JOIN dg_full.meta_schema_ref_table s ON bb.schema_src_id = s.schema_src_id
   LEFT JOIN tmp_pp pp ON pp.object_src_id::name::text = bb.node_src_id AND pp.schema_src_id::name = bb.schema_src_id AND pp.property_type_src_id = 6
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_node;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_node - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_node_add - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_node_add AS
SELECT 
tt.schema_src_id,
tt.node_src_id,
tt.src_cd , 
tt.is_active ,
CASE WHEN  (tt.schema_src_id::TEXT ||'||' || tt.node_src_id) IN (SELECT node_id FROM tmp_owner) THEN 1
ELSE 0 
END AS is_owner
FROM (
SELECT DISTINCT 
t.src_schema_src_id  AS schema_src_id,
t.src_node_src_id AS node_src_id,
t.src_cd , t.is_active 
FROM 
s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t
WHERE t.dl_file_id::int8 IN (SELECT max(t1.dl_file_id::int8) FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t1) 
UNION 
SELECT distinct 
t.target_schema_src_id  AS schema_src_id,
t.target_node_src_id AS node_src_id,
t.src_cd , t.is_active 
FROM 
s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t
WHERE t.dl_file_id::int8 IN (SELECT max(t1.dl_file_id::int8) FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t1) 
) tt
WHERE (tt.schema_src_id,tt.node_src_id) NOT IN (SELECT m.schema_src_id,m.node_src_id FROM temp_meta_node m)
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_node_add;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_node_add - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_node_ref_table';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_node_ref_table;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_node_ref_table'|| chr(9) || v_deleted_row::text;

/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_node_ref_table';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_node_ref_table 
(
node_src_id,
schema_src_id,
load_dttm,
src_cd,
wf_load_id,
eff_from_dttm,
eff_to_dttm,
last_seen_dttm,
node_cd,
node_name,
node_type_src_id,
is_active,
created_dt,
modified_dt,
node_type_cd,
is_owner
)
SELECT 
n.node_src_id::varchar(250) ,
n.schema_src_id::varchar(250),
n.load_dttm::timestamp,
n.src_cd::varchar(20),
n.wf_load_id::NUMERIC(22),
n.eff_from_dttm::timestamp,
n.eff_to_dttm::timestamp,
n.last_seen_dttm::timestamp,
n.wf_id::varchar(250) AS node_cd,
n.node_name::text,
n.node_type_src_id::int4,
n.is_active::bool,
n.created_dt::date,
n.modified_dt::date,
n.node_type_cd::varchar(20),
n.is_owner::int4
FROM temp_meta_node n
UNION
SELECT 
n1.node_src_id,
n1.schema_src_id,
current_timestamp AS load_dttm,
n1.src_cd,
-1::numeric(22) AS wf_load_id,
'1999-01-01 00:00:00'::timestamp AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp AS eff_to_dttm,
current_timestamp AS last_seen_dttm,
n1.node_src_id::varchar(250)  AS node_cd,
n1.node_src_id::text AS node_name,
NULL::int4 AS node_type_src_id,
n1.is_active::bool,
current_date AS created_dt,
current_date AS modified_dt,
NULL::varchar(20)  AS node_type_cd,
n1.is_owner::int4
FROM temp_meta_node_add n1
;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_node_ref_table' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_node_ref_table - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_node;
DROP TABLE IF EXISTS temp_meta_node_add;
DROP TABLE IF EXISTS tmp_owner;
DROP TABLE IF EXISTS tmp_gp_obj;
DROP TABLE IF EXISTS tmp_qs_obj;
DROP TABLE IF EXISTS tmp_meta_sg_category;
DROP TABLE IF EXISTS tmp_tfs;
DROP TABLE IF EXISTS tmp_hdp;
DROP TABLE IF EXISTS tmp_hdp_obj;
DROP TABLE IF EXISTS tmp_smd;
DROP TABLE IF EXISTS tmp_bb;
DROP TABLE IF EXISTS tmp_pp;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;




































$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_node_ref_table_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-01-13 Entity's attributes change 
 * 2025-04-11 Add QS nodes
 * 2025-30-10 LGI add SMD nodes 
 * 2025-11-19 add tmp_TFS 
 * 2025-12-05 change node type TFS
 * 
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_node_ref_table';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_node_ref_table';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

ANALYZE dg_full.meta_schema_ref_table;
ANALYZE dg_full.meta_edge_link;
ANALYZE s_grnplm_as_cib_gm_ods_qlik.lineage;
ANALYZE s_grnplm_as_cib_gm_dg.meta_node_type_ref_table;
ANALYZE s_grnplm_as_cib_gm_ods_ctl.category;


CREATE TEMPORARY TABLE tmp_owner AS 
SELECT DISTINCT 
       s.src_node_id::TEXT AS node_id,
       s.src_node_src_id::TEXT,
       s.src_schema_src_id::TEXT
FROM dg_full.meta_edge_link s
WHERE ( s.src_node_type_cd = 'Table')
UNION
SELECT DISTINCT 
       t.target_node_id::TEXT AS node_id,
       t.target_node_src_id::TEXT,
       t.target_schema_src_id::TEXT 
FROM dg_full.meta_edge_link t
WHERE (t.tgt_node_type_cd = 'Table')
DISTRIBUTED BY (node_id) 
;
RAISE NOTICE 'tmp_owner';

-- список объектов GP
CREATE TEMPORARY TABLE tmp_gp_obj AS 
WITH tt AS (
SELECT 
            replace(pgc.relname::text, '"'::text, ''::text)::TEXT AS node_src_id,
            pgn.nspname::TEXT AS schema_src_id,
            pgc.relname AS node_cd,
            /* pgn.nspname::TEXT || '||'::Text || pgc.relname::TEXT */
            obj_description(pgc.oid) AS node_name,
                CASE
                    WHEN pgc.relkind = 't'::"char" THEN 1
                    WHEN pgc.relkind = 'r'::"char" THEN 1
                    WHEN pgc.relkind = 'p'::"char" THEN 1
                    WHEN pgc.relkind = 'v'::"char" THEN 2
                    WHEN pgc.relkind = 'm'::"char" THEN 3
                    ELSE NULL::integer
                END AS node_type_src_id,
            CASE WHEN  (pgn.nspname ||'||' || replace(pgc.relname::text, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_src_id::name
          WHERE 1 = 1 AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['t'::"char", 'r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        UNION
         SELECT 
            replace(pgp.proname::text, '"'::text, ''::text)::TEXT AS node_src_id,
            pgn.nspname::TEXT AS schema_src_id,
            pgp.proname AS node_cd,
            pgn.nspname::TEXT || '||'::Text || pgp.proname AS node_name,
            4 AS node_type_src_id,
            1 AS is_owner
           FROM pg_proc pgp
             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_src_id::name
          WHERE 1 = 1
)
SELECT 
            tt.node_src_id,
            tt.schema_src_id,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            tt.node_cd,
            /* pgn.nspname::TEXT || '||'::Text || pgc.relname::TEXT */
            tt.node_name,
            tt.node_type_src_id,
            n.node_type_cd,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            tt.is_owner
FROM tt
JOIN s_grnplm_as_cib_gm_dg.meta_node_type_ref_table n ON tt.node_type_src_id = n.node_type_src_id
DISTRIBUTED BY (schema_src_id, node_src_id)
;
RAISE NOTICE 'tmp_gp_obj';

-- список объектов QS
CREATE TEMPORARY TABLE tmp_qs_obj  AS 
WITH 
tmp_tt AS 
(
 SELECT DISTINCT  
 l.app_key, l.lng_flow , COALESCE(l.lng_src_flag,'-') AS lng_src_flag, l.lng_object_type , l.lng_application
 , CASE 
   WHEN POSITION ('_20' IN l.lng_object) <> 0  THEN regexp_replace(REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://'),'\_20.*?\.','.')
   ELSE REPLACE(REPLACE(REPLACE(REPLACE(l.lng_object,',',''),'\','/'),'//','/'),'lib:/','lib://') END AS lng_object_1
 FROM s_grnplm_as_cib_gm_ods_qlik.lineage l 
 WHERE 1=1
  AND lng_object NOT LIKE '%ArchivedLogsFolder%'
  AND lng_object NOT LIKE '%ServerLogFolder%'
  AND lng_object NOT LIKE '%/Meta/AppSrc/%'
  AND l.lng_application NOT LIKE '%Find Applications SQL Sources%'
 )
, tmp_tt1 AS 
(
SELECT 
 tt.app_key, tt.lng_flow , tt.lng_src_flag, tt.lng_object_type , tt.lng_application, tt.lng_object_1
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  ELSE substring(tt.lng_object_1 FROM 1 FOR (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) - 1)
  END  AS schema_src_id
, CASE WHEN tt.lng_object_type = 'SQL'
  THEN substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('.' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  ELSE substring(tt.lng_object_1 FROM (length(tt.lng_object_1) - POSITION('/' IN reverse(tt.lng_object_1)) + 1 ) + 1)
  END AS node_src_id
FROM tmp_tt tt
) 
, tt_main AS (
SELECT 
  tt1.schema_src_id
, tt1.node_src_id
, tt1.lng_application
, tt1.lng_flow
, tt1.app_key
, CASE WHEN  tt1.lng_object_type = 'TXT' THEN 8
       WHEN  tt1.lng_object_type = 'EXCEL' THEN 8
       WHEN  tt1.lng_object_type = 'SQL' THEN COALESCE(gp.node_type_src_id ,1)
       WHEN  tt1.lng_object_type = 'QVD' THEN 6
       WHEN  tt1.lng_object_type = 'CSV' THEN 8
       WHEN  tt1.lng_object_type = 'APP' THEN 13
  END AS  node_type_src_id
, CASE WHEN  tt1.lng_object_type = 'TXT' THEN 'Excel\CSV'
       WHEN  tt1.lng_object_type = 'EXCEL' THEN 'Excel\CSV'
       WHEN  tt1.lng_object_type = 'SQL' THEN COALESCE(gp.node_type_cd , 'Table')
       WHEN  tt1.lng_object_type = 'QVD' THEN 'QVD'
       WHEN  tt1.lng_object_type = 'CSV' THEN 'Excel\CSV'
       WHEN  tt1.lng_object_type = 'APP' THEN'Application QS'
  END AS  node_type_cd
FROM tmp_tt1 tt1
LEFT JOIN tmp_gp_obj gp ON gp.schema_src_id = tt1.schema_src_id
                       AND gp.node_src_id = tt1.node_src_id
)
, tt_node AS (
SELECT DISTINCT
t1.node_src_id AS node_src_id,
t1.schema_src_id AS schema_src_id,
'QS' AS src_cd,
t1.node_src_id AS node_cd,
t1.schema_src_id  || '||' || t1.node_src_id AS node_name,
t1.node_type_src_id AS node_type_src_id,
TRUE::bool AS is_active,
t1.node_type_cd AS node_type_cd
FROM tt_main t1
UNION 
SELECT DISTINCT
t2.lng_application AS node_src_id,
t2.lng_flow AS schema_src_id,
'QS' AS src_cd,
t2.app_key AS node_cd,
t2.lng_flow  || '||' || t2.lng_application AS node_name,
13::int4 AS node_type_src_id,
TRUE::bool AS is_active,
'Application QS'::text AS node_type_cd
FROM tt_main t2
)
SELECT 
n.node_src_id,
n.schema_src_id,
n.src_cd,
n.node_cd,
n.node_name,
n.node_type_src_id,
n.is_active,
n.node_type_cd
FROM tt_node n
WHERE NOT EXISTS (SELECT * FROM tmp_gp_obj o WHERE o.schema_src_id = n.schema_src_id AND o.node_src_id = n.node_src_id)
DISTRIBUTED BY (schema_src_id, node_src_id) 
;
RAISE NOTICE 'tmp_qs_obj';

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_meta_sg_category - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_meta_sg_category AS 
WITH RECURSIVE sg_category(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parentid   AS parent_id,
            g.name::text AS name_,
            1 AS depth,
            ARRAY[g.name::TEXT] AS path,
            false  AS cycle,
            g.name AS root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g -- s_grnplm_as_cib_gm_stg_espd.ctl_category g
          WHERE 1 = 1 
          AND g.parentid = 0 
          AND g.id in (1764,1964)  -- 1964 - ift
          AND g.deleted = FALSE
        UNION ALL
         SELECT g1.id,
            g1.parentid   AS parent_id,
            g1.name::TEXT AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name::TEXT,
            g1.name::TEXT = ANY (p.path),
            p.root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g1 --  s_grnplm_as_cib_gm_stg_espd.ctl_category g1
             JOIN sg_category p ON p.id = g1.parentid
          WHERE 1 = 1 AND NOT p.cycle
        )
 SELECT 
    sg_category.id,
    sg_category.parent_id,
    sg_category.name_,
    sg_category.depth,
    sg_category.path,
    sg_category.cycle,
    sg_category.root_name_id
   FROM sg_category
DISTRIBUTED BY (id);
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_meta_sg_category;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_meta_sg_category - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


-- список обьектов СМД поставщик и потребитель
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_smd - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_smd AS 
SELECT DISTINCT    -- Мы публикуем: dm -> продукт смд -> подписки потребитиелей
p.meta_product_name AS node_src_id,
lower( p.pm_name)  AS schema_src_id,
'SMD'::text AS src_cd,
p.data_product_name AS node_cd, 
lower(p.pm_name)  || '||' || p.meta_product_name AS node_name,
14::int4  AS node_type_src_id,
TRUE::bool AS is_active,
p.eff_date_ts::date AS  created_dt,
p.eff_date_ts::date AS  modified_dt,
'SMD' AS   node_type_cd,
1::int4 AS  is_owner
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report p 
WHERE 1=1
 AND (p.data_product_uuid, p.eff_date_ts) in (SELECT pr.data_product_uuid, max(pr.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr group by 1)
 AND p."cluster" ='GP_GM1' 
 AND p.pm_name ILIKE '%tib%'
 AND p.conf_item_product = 'CI02533826'
UNION
SELECT DISTINCT  -- Мы забираем: источник -> подписка смд -> stg -> ods -> dm 
lower(dt.pm_name) AS node_src_id,
lower(pr.pm_name)  AS schema_src_id,
'SMD'::text AS src_cd,
pr.data_product_name AS node_cd, 
lower(pr.pm_name) || '||' || lower(dt.pm_name) AS node_name,
1::int4  AS node_type_src_id,
TRUE::bool AS is_active,
pr.eff_date_ts::date AS  created_dt,
pr.eff_date_ts::date AS  modified_dt,
'SMD'::text AS   node_type_cd,
1::int4 AS  is_owner 
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_subscription_report s -- подписки
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_subscr_dp_rel r ON  s.subscription_uuid = r.subscription_uuid
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr  ON pr.stock_element_id = r.stock_element_id_sch
JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND s.subscription_uuid = n.node_src_id -- наши подписки из CTL
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table dt ON dt.stock_element_id_sch = pr.stock_element_id
WHERE 1=1
AND (pr.data_product_uuid, pr.eff_date_ts) in (SELECT pr1.data_product_uuid, max(pr1.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr1 group by 1)
AND s.subscription_status_display_name = 'Активна'
UNION
SELECT DISTINCT  --  связь таблиц с внешними продуктами
pr.meta_product_name AS node_src_id,
lower( pr.pm_name)  AS schema_src_id,
'SMD'::text AS src_cd,
pr.data_product_name AS node_cd, 
lower(pr.pm_name)  || '||' || pr.meta_product_name AS node_name,
14::int4  AS node_type_src_id,
TRUE::bool AS is_active,
pr.eff_date_ts::date AS  created_dt,
pr.eff_date_ts::date AS  modified_dt,
'SMD' AS   node_type_cd,
1::int4 AS  is_owner
FROM s_grnplm_as_cib_gm_stg_espd.v_smd_subscription_report s -- подписки
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_subscr_dp_rel r ON  s.subscription_uuid = r.subscription_uuid
JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr  ON pr.stock_element_id = r.stock_element_id_sch
JOIN dg_full.meta_node_ref_table n ON  n.src_cd in ( 'CTL'::text)  AND s.subscription_uuid = n.node_src_id -- наши подписки из CTL
--JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table dt ON dt.stock_element_id_sch = pr.stock_element_id
WHERE 1=1
AND (pr.data_product_uuid, pr.eff_date_ts) in (SELECT pr1.data_product_uuid, max(pr1.eff_date_ts) FROM s_grnplm_as_cib_gm_stg_espd.v_smd_data_product_report pr1 group by 1)
AND s.subscription_status_display_name = 'Активна'
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_smd;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_smd - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


-- список объектов Hadoop\Hive
CREATE TEMPORARY TABLE tmp_hdp AS 
          SELECT 
                w.id AS wf_id,
                w.name_ AS wf_nm,
                --------------------
                max(CASE
                    WHEN cp.param::text IN ('hive_schema_name'::TEXT,'hive_schema_name_act'::text) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_schema_name,
                max(CASE
                    WHEN cp.param::text IN ('hive_table_name'::TEXT, 'hive_table_name_act'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_table_name,
                ------
                max(CASE
                    WHEN cp.param::text = 'hive_schema_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_snp_schema_name,
                max(CASE
                    WHEN cp.param::text = 'hive_table_name_act_snp'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_snp_table_name,
                -------------
                max(CASE
                    WHEN cp.param::text = 'hive_schema_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_diff_schema_name,
                max(CASE
                    WHEN cp.param::text = 'hive_table_name_act_diff'::text THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS src_hdp_diff_table_name
                -------------
             FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN tmp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 
            AND w.deleted = false 
            AND (w.profile_id = ANY (ARRAY[329, 334])) 
            AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
          GROUP BY w.id, w.name_
  DISTRIBUTED BY (wf_id)       
;
RAISE NOTICE 'tmp_hdp';

-- список объектов TFS
CREATE TEMPORARY TABLE tmp_tfs AS 
          SELECT -- DISTINCT 
                max(w.id) AS wf_id,
                w.name_ AS wf_nm,
                --------------------
                max(CASE
                    WHEN cp.param::text IN ('file_path_source'::TEXT, 'path_to_local'::TEXT, 'path_to_tfs'::TEXT, 'path_from_local'::TEXT) THEN cp.prior_value
                    ELSE NULL::character varying
                END)::text AS path_tfs
                -------------
             FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
             JOIN tmp_meta_sg_category cc 
               ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp 
               ON w.id = cp.wf_id
          WHERE 1 = 1 
            AND w.deleted = false 
            AND (w.profile_id = ANY (ARRAY[329, 334])) 
            AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
          GROUP BY w.name_
  DISTRIBUTED BY (wf_id)       
;
RAISE NOTICE 'tmp_tfs';


CREATE TEMPORARY TABLE tmp_hdp_obj AS 
SELECT DISTINCT 
            h0.wf_id,
            h0.src_hdp_table_name::TEXT AS node_src_id ,
            h0.src_hdp_schema_name::TEXT  AS schema_src_id ,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            h0.src_hdp_table_name::TEXT AS node_cd,
            h0.src_hdp_schema_name::TEXT || '||'::Text || h0.src_hdp_table_name::TEXT AS node_name,
            1::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  (h0.src_hdp_schema_name::TEXT ||'||' || replace(h0.src_hdp_table_name::TEXT, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
FROM tmp_hdp h0 
WHERE h0.src_hdp_table_name IS NOT NULL AND h0.src_hdp_schema_name IS NOT NULL 
UNION 
SELECT DISTINCT 
            h1.wf_id,  
            h1.src_hdp_diff_table_name::TEXT AS node_src_id,
            h1.src_hdp_diff_schema_name::TEXT AS schema_src_id,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            h1.src_hdp_diff_table_name::TEXT AS node_cd,
            h1.src_hdp_diff_schema_name::TEXT || '||'::Text || h1.src_hdp_diff_table_name::TEXT AS node_name,
            1::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  (h1.src_hdp_diff_schema_name::TEXT ||'||' || replace(h1.src_hdp_diff_table_name::TEXT, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
FROM tmp_hdp h1 
WHERE h1.src_hdp_diff_table_name IS NOT NULL AND h1.src_hdp_diff_schema_name IS NOT NULL 
UNION 
SELECT DISTINCT 
            h2.wf_id,
            h2.src_hdp_snp_table_name::TEXT AS node_src_id,
            h2.src_hdp_snp_schema_name::TEXT AS schema_src_id,
            now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            h2.src_hdp_snp_table_name::TEXT AS node_cd,
            h2.src_hdp_snp_schema_name::TEXT || '||'::Text || h2.src_hdp_snp_table_name::TEXT AS node_name,
            1::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  (h2.src_hdp_snp_schema_name::TEXT ||'||' || replace(h2.src_hdp_snp_table_name::TEXT, '"'::text, ''::text)) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner
FROM tmp_hdp h2 
WHERE h2.src_hdp_snp_table_name IS NOT NULL AND h2.src_hdp_snp_schema_name IS NOT NULL 
DISTRIBUTED BY (schema_src_id, node_src_id)
;
RAISE NOTICE 'tmp_hdp_obj';


CREATE TEMPORARY TABLE tmp_bb AS
SELECT DISTINCT 
            t.wf_id,
            t.wf_nm::TEXT AS node_src_id,
            t.path_tfs::TEXT::TEXT AS schema_src_id,
            now() AS load_dttm,
            'CTL'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            t.wf_id::TEXT AS node_cd,
            t.path_tfs::TEXT || '||'::Text || t.wf_nm::TEXT AS node_name,
            17::int4 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            CASE WHEN  ('TFS'::TEXT ||'||' || t.path_tfs) IN (SELECT node_id FROM tmp_owner) THEN 1
            ELSE 0 
            END AS is_owner,
            'Folder'::text AS schema_type
FROM tmp_tfs t 
WHERE t.path_tfs IS NOT NULL 
UNION 
SELECT 
            h.wf_id,
            h.node_src_id::TEXT AS node_src_id,
            h.schema_src_id::TEXT AS schema_src_id,
            h.load_dttm,
            h.src_cd,
            h.wf_load_id,
            h.eff_from_dttm,
            h.eff_to_dttm,
            h.last_seen_dttm,
            h.node_cd,
            h.node_name,
            h.node_type_src_id,
            h.is_active,
            h.created_dt,
            h.modified_dt,
            h.is_owner,
            'Folder'::text AS schema_type
           FROM tmp_hdp_obj h
UNION
SELECT 
            '-1'::int8 AS wf_id,
            g.node_src_id::TEXT AS node_src_id,
            g.schema_src_id::TEXT AS schema_src_id,
            g.load_dttm,
            g.src_cd,
            g.wf_load_id,
            g.eff_from_dttm,
            g.eff_to_dttm,
            g.last_seen_dttm,
            g.node_cd,
            g.node_name,
            g.node_type_src_id,
            g.is_active,
            g.created_dt,
            g.modified_dt,
            g.is_owner,
            'Folder'::text AS schema_type
           FROM tmp_gp_obj g
         UNION
         SELECT
            '-1'::int8 AS wf_id,
            s.node_src_id,
            s.schema_src_id,
            current_timestamp AS load_dttm,
            s.src_cd,
            -1::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            current_timestamp AS last_seen_dttm,
            s.node_cd::text, 
            s.node_name,
            s.node_type_src_id,
            s.is_active,
            s.created_dt,
            s.modified_dt,
            s.is_owner,
            'Flow'::text AS schema_type
            FROM tmp_smd  s
            WHERE 1=1
        UNION
         SELECT 
            w.id AS wf_id,
            w.name_::TEXT AS node_src_id,
            cc.name_::TEXT AS schema_src_id,
            now() AS load_dttm,
            'CTL'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            w.name_::text AS node_cd,
            (cc.name_ || '||'::text) || w.name_::text AS node_name,
            5 AS node_type_src_id,
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
                CASE
                    WHEN (w.id IN ( SELECT cp.wf_id
                       FROM dg_full.vctl_param cp -- s_grnplm_as_cib_gm_stg_.ctl_param cp
                      WHERE cp.wf_id = w.id AND lower(cp.param::text) ~~ '%connectionlake%'::text AND cp.prior_value::text ~~ '%TIB%'::text)) THEN 1
                    ELSE 0
                END AS is_owner,
            'Cathegory'::text AS schema_type
           FROM tmp_meta_sg_category cc
           JOIN dg_full.vctl_wf w --  s_grnplm_as_cib_gm_stg_espd.ctl_wf w 
             ON cc.id = w.category_id
          WHERE 1 = 1 AND w.deleted = false AND (w.profile_id = ANY (ARRAY[150, 329, 334]))
                      AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1 -- s_grnplm_as_cib_gm_stg_espd.ctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param::text) ~~ '%connectionlake%'::text AND cp1.prior_value::text ~~ '%TIB%'::TEXT -- '%TIBDS%'::text
                  GROUP BY cp1.wf_id))
        UNION
         SELECT DISTINCT 
            e.id AS wf_id,
            e.name_::TEXT AS node_src_id,
            CASE WHEN POSITION('/' IN reverse(e."path")) <> 0 AND POSITION(e.name_::TEXT IN e."path") <> 0 
                 THEN substring(e."path" FROM 1 FOR (length(e."path") - POSITION('/' IN reverse(e."path")) + 1 ) - 1) 
                 ELSE DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e.name_ , 'xx'::TEXT, e."path" )
            END  AS schema_src_id, -- путь до entity
            now() AS load_dttm,
            'CTL'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            now() AS last_seen_dttm,
            e.id::TEXT AS node_cd,
            DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path")::TEXT || '||'::Text || e.name_::TEXT AS node_name,
            10 AS node_type_src_id, -- Entity
            true AS is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            1 AS is_owner,
            'Cathegory'::text AS schema_type
           FROM dg_full.vmeta_sg_entity ee_1
           JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity e 
             ON ee_1.id = e.id
          WHERE 1 = 1
          AND (e.id::int8::text IN (SELECT entity_id FROM dg_full.vctl_wf_event_sched)
           OR  e.id::int8::text IN (SELECT entity_id FROM dg_full.vctl_init_lock_check)
           OR  e.id::int8::text IN (SELECT entity_id FROM dg_full.vctl_init_lock_set)
          )
          GROUP BY e.id, 
                   e.name_::TEXT, 
                   e."path",
                   CASE WHEN POSITION('/' IN reverse(e."path")) <> 0 AND POSITION(e.name_::TEXT IN e."path") <> 0 
                 THEN substring(e."path" FROM 1 FOR (length(e."path") - POSITION('/' IN reverse(e."path")) + 1 ) - 1) 
                 ELSE DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e.name_ , 'xx'::TEXT, e."path" ) END
        UNION
         SELECT 
            '-1'::int8 AS wf_id,
            replace(m.node_src_id::text, '"'::text, ''::text)::TEXT AS node_src_id,
            m.schema_src_id::TEXT AS schema_src_id,
            current_timestamp AS load_dttm,
            m.src_cd,
            -1::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            current_timestamp AS last_seen_dttm,
            m.node_cd::TEXT,
            m.schema_src_id::TEXT || '||' || replace(m.node_src_id::text, '"'::text, ''::text)::TEXT AS node_name,
            m.node_type_src_id,
            m.is_active,
            'now'::text::date AS created_dt,
            'now'::text::date AS modified_dt,
            1 AS is_owner,
            ms.schema_type
         FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_node_ref_table m -- замена на АС СПОД (Ввод данных)
         LEFT JOIN dg_full.meta_schema_ref_table ms ON m.schema_src_id = ms.schema_src_id 
         WHERE 1=1
           AND m.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_node_ref_table h1)
           AND m.src_cd::text <> 'CTL'::TEXT
           -- !! AND m.src_cd::text <> 'SMD'::TEXT -- !! SMD убрать
           AND NOT EXISTS (SELECT * FROM tmp_gp_obj o WHERE o.node_src_id::text = m.node_src_id::text AND o.schema_src_id::text = m.schema_src_id::text)     
        UNION
         SELECT 
            '-1'::int8 AS wf_id,
            q.node_src_id,
            q.schema_src_id,
            current_timestamp AS load_dttm,
            q.src_cd,
            -1::integer AS wf_load_id,
            '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
            '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
            current_timestamp AS last_seen_dttm,
            q.node_cd::TEXT,
            q.node_name,
            q.node_type_src_id,
            q.is_active,
            current_timestamp AS created_dt,
            current_timestamp AS modified_dt,
            1 AS is_owner,
            'Flow'::text AS schema_type
         FROM tmp_qs_obj q
         WHERE 1=1
DISTRIBUTED BY (schema_src_id, node_src_id)
;
RAISE NOTICE 'tmp_bb';

/* Массив доп.свойств */
CREATE TEMPORARY TABLE tmp_pp AS
SELECT m.object_src_id,
       m.schema_src_id,
       m.property_type_src_id,
       m.property_val 
FROM dg_full.vmeta_property_hsat m
WHERE (m.load_dttm,m.object_src_id,m.schema_src_id, m.property_type_src_id) 
IN (SELECT 
       max(m0.load_dttm) AS max,
       m0.object_src_id,
       m0.schema_src_id,
       m0.property_type_src_id
    FROM dg_full.vmeta_property_hsat m0
    GROUP BY m0.object_src_id, m0.schema_src_id, m0.property_type_src_id
  )
DISTRIBUTED BY (schema_src_id, object_src_id, property_type_src_id)
;
RAISE NOTICE 'tmp_pp';
      
INSERT INTO dg_full.meta_schema_ref_table 
(schema_src_id,schema_cd,descr,"type",schema_type,load_dttm,wf_load_id,src_cd)
WITH tab AS (
SELECT DISTINCT trim(REPLACE ( REPLACE ( regexp_matches  (description::text,'s_grnplm_as\S*?\s','g')::TEXT,'{"',''),'"}','')) AS  descr  
FROM s_grnplm_as_cib_ods_internal_jira_sigma.jiraissue
WHERE project = '258300' AND summary LIKE '%[PPM] Ввод РРМ GreenPlum%' 
AND description ILIKE '%TIBDS%'
)
SELECT 
DISTINCT 
b.schema_src_id::TEXT AS schema_src_id,
substring(b.schema_src_id,1,100)::TEXT AS schema_cd,
b.schema_src_id::TEXT AS descr,
'ПРОМ' AS "type",
b.schema_type AS schema_type,
current_timestamp AS load_dttm,
-1::int8  AS wf_load_id,
b.src_cd AS src_cd
FROM tmp_bb b
WHERE NOT EXISTS (SELECT schema_src_id FROM dg_full.meta_schema_ref_table t WHERE t.schema_src_id = b.schema_src_id::text)
AND b.schema_src_id IS NOT NULL
UNION 
SELECT 
jt.descr::TEXT AS schema_src_id,
substring(jt.descr::TEXT, 1, 100)::TEXT AS schema_cd,
jt.descr::TEXT AS descr,
'ПРОМ' AS "type",
'Schema'::TEXT AS schema_type,
current_timestamp AS load_dttm,
-1::int8  AS wf_load_id,
'GP'::TEXT AS src_cd
FROM (SELECT * FROM dg_full.meta_schema_ref_table m1
WHERE 1=1
AND m1.schema_type= 'Schema'
AND m1.schema_src_id NOT LIKE '%_ld_%'
) m
FULL JOIN  tab  jt ON m.schema_src_id::TEXT = jt.descr::text
WHERE 1=1
AND m.schema_src_id IS NULL 
;
RAISE NOTICE 'insert into meta_schema_ref_table';


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_node - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_node AS
SELECT 
    bb.wf_id,
    bb.node_src_id::TEXT AS node_src_id,
    bb.schema_src_id::TEXT AS schema_src_id,
    bb.load_dttm,
    bb.src_cd,
    bb.wf_load_id,
    bb.eff_from_dttm,
    bb.eff_to_dttm,
    bb.last_seen_dttm,
    bb.node_cd,
    bb.node_name,
    bb.node_type_src_id,
    CASE
     WHEN coalesce(pp.property_val,'1') = '1'::text THEN TRUE
     WHEN coalesce(pp.property_val,'1') = '0'::text THEN FALSE
     ELSE FALSE
    END AS is_active,
    bb.created_dt,
    bb.modified_dt,
    ee.node_type_cd,
    bb.is_owner
   FROM tmp_bb bb
   JOIN dg_full.meta_node_type_ref_table ee ON bb.node_type_src_id = ee.node_type_src_id
   JOIN dg_full.meta_schema_ref_table s ON bb.schema_src_id = s.schema_src_id
   LEFT JOIN tmp_pp pp ON pp.object_src_id::name::text = bb.node_src_id AND pp.schema_src_id::name = bb.schema_src_id AND pp.property_type_src_id = 6
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_node;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_node - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_node_add - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_node_add AS
SELECT 
tt.schema_src_id,
tt.node_src_id,
tt.src_cd , 
tt.is_active ,
CASE WHEN  (tt.schema_src_id::TEXT ||'||' || tt.node_src_id) IN (SELECT node_id FROM tmp_owner) THEN 1
ELSE 0 
END AS is_owner
FROM (
SELECT DISTINCT 
t.src_schema_src_id  AS schema_src_id,
t.src_node_src_id AS node_src_id,
t.src_cd , t.is_active 
FROM 
s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t
WHERE t.dl_file_id::int8 IN (SELECT max(t1.dl_file_id::int8) FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t1) 
UNION 
SELECT distinct 
t.target_schema_src_id  AS schema_src_id,
t.target_node_src_id AS node_src_id,
t.src_cd , t.is_active 
FROM 
s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t
WHERE t.dl_file_id::int8 IN (SELECT max(t1.dl_file_id::int8) FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link t1) 
) tt
WHERE (tt.schema_src_id,tt.node_src_id) NOT IN (SELECT m.schema_src_id,m.node_src_id FROM temp_meta_node m)
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_node_add;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_node_add - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_node_ref_table';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_node_ref_table;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_node_ref_table'|| chr(9) || v_deleted_row::text;

/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_node_ref_table';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_node_ref_table 
(
node_src_id,
schema_src_id,
load_dttm,
src_cd,
wf_load_id,
eff_from_dttm,
eff_to_dttm,
last_seen_dttm,
node_cd,
node_name,
node_type_src_id,
is_active,
created_dt,
modified_dt,
node_type_cd,
is_owner
)
SELECT 
n.node_src_id::varchar(250) ,
n.schema_src_id::varchar(250),
n.load_dttm::timestamp,
n.src_cd::varchar(20),
n.wf_load_id::NUMERIC(22),
n.eff_from_dttm::timestamp,
n.eff_to_dttm::timestamp,
n.last_seen_dttm::timestamp,
n.wf_id::varchar(250) AS node_cd,
n.node_name::text,
n.node_type_src_id::int4,
n.is_active::bool,
n.created_dt::date,
n.modified_dt::date,
n.node_type_cd::varchar(20),
n.is_owner::int4
FROM temp_meta_node n
UNION
SELECT 
n1.node_src_id,
n1.schema_src_id,
current_timestamp AS load_dttm,
n1.src_cd,
-1::numeric(22) AS wf_load_id,
'1999-01-01 00:00:00'::timestamp AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp AS eff_to_dttm,
current_timestamp AS last_seen_dttm,
n1.node_src_id::varchar(250)  AS node_cd,
n1.node_src_id::text AS node_name,
NULL::int4 AS node_type_src_id,
n1.is_active::bool,
current_date AS created_dt,
current_date AS modified_dt,
NULL::varchar(20)  AS node_type_cd,
n1.is_owner::int4
FROM temp_meta_node_add n1
;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_node_ref_table' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_node_ref_table - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_node;
DROP TABLE IF EXISTS temp_meta_node_add;
DROP TABLE IF EXISTS tmp_owner;
DROP TABLE IF EXISTS tmp_gp_obj;
DROP TABLE IF EXISTS tmp_qs_obj;
DROP TABLE IF EXISTS tmp_meta_sg_category;
DROP TABLE IF EXISTS tmp_tfs;
DROP TABLE IF EXISTS tmp_hdp;
DROP TABLE IF EXISTS tmp_hdp_obj;
DROP TABLE IF EXISTS tmp_smd;
DROP TABLE IF EXISTS tmp_bb;
DROP TABLE IF EXISTS tmp_pp;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;





































$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_object_list(in p_target_sql text, schema_src_id text, node_src_id text)
	RETURNS TABLE (schema_src_id text, node_src_id text)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
    
    
DECLARE
    v_params          text default '';
    v_res_statements  text default '';
BEGIN
    /* Добавить логгирование  */
    v_params := format('p_target_sql = %I ', 
                        p_target_sql   
                      );

-- vmeta_node_ref_table
CREATE TEMPORARY TABLE temp_vmeta_node_ref_table AS
SELECT 
    bb.node_src_id::name AS node_src_id,
    bb.schema_src_id,
    bb.src_cd,
    bb.node_type_src_id
   FROM ( SELECT 
            replace(pgc.relname::text, '"'::text, ''::text) AS node_src_id,
            pgn.nspname AS schema_src_id,
            'GP'::text AS src_cd,
                CASE
                    WHEN pgc.relkind = ANY (ARRAY['t'::"char", 'r'::"char", 'p'::"char"]) THEN 1
                    WHEN pgc.relkind = 'v'::"char" THEN 2
                    WHEN pgc.relkind = 'm'::"char" THEN 3
                    ELSE NULL::integer
                END AS node_type_src_id
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             --JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_cd::name
          WHERE 1 = 1 AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['t'::"char", 'r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        UNION
         SELECT 
            replace(pgp.proname::text, '"'::text, ''::text) AS node_src_id,
            pgn.nspname AS schema_src_id,
            'GP'::text AS src_cd,
            4 AS node_type_src_id
           FROM pg_proc pgp
             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
             --JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_cd::name
          WHERE 1 = 1
        UNION
         SELECT 
            replace(m.node_src_id::text, '"'::text, ''::text) AS node_src_id,
            m.schema_src_id,
            m.src_cd,
            m.node_type_src_id
           FROM dg_full.meta_node_ref_table m
          ) bb
 DISTRIBUTED BY (node_src_id, schema_src_id);
 ANALYZE temp_vmeta_node_ref_table;
 
-- vmeta_edge_link
CREATE TEMPORARY TABLE temp_vmeta_edge_link AS
WITH temp_p AS (
         SELECT 
            replace(replace(regexp_replace(btrim(p_target_sql), '[\n\r\t\v]+'::text, ''::text), '"'::text, ''::text),'''','') AS prosrc
        )
        , temp_tt AS (
         SELECT 
            t.schema_src_id,
            replace(t.node_src_id::text, '"'::text, ''::text) AS node_src_id,
            p.prosrc,
                CASE
                    WHEN /*lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || ' %'::text) 
                      OR lower(p.prosrc) ~~ ((t.schema_src_id::text) || '.'::text || t.node_src_id::text) 
                      OR lower(p.prosrc) ~* ((t.schema_src_id::text) || '.'::text || t.node_src_id::text)*/
                         lower(p.prosrc) = lower(t.schema_src_id::text || '.'::text || t.node_src_id::text)
                      THEN 4
                    ELSE NULL::integer
                END AS ww4
           FROM temp_vmeta_node_ref_table t
             CROSS JOIN temp_p p
)
 SELECT DISTINCT 
                tt.schema_src_id,
                tt.node_src_id,
                tt.ww4 AS edge_type_src_id
           FROM temp_tt tt
          WHERE 1 = 1 
            AND (tt.ww4 IS NOT NULL) 
            AND tt.schema_src_id <> 'pg_catalog'::name
DISTRIBUTED BY (schema_src_id, node_src_id);
ANALYZE temp_vmeta_edge_link;

 
v_res_statements := v_res_statements || chr(10) || '/* Out table: */'|| chr(10) || 'temp_vmeta_edge_link';

RETURN query
SELECT 
  l.schema_src_id::text 
, l.node_src_id::text
FROM temp_vmeta_edge_link l
;

DROP TABLE temp_vmeta_node_ref_table;
DROP TABLE temp_vmeta_edge_link;

PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, 'return_meta_object_list' , -1, -1, 0::int4);

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLSTATE||'::'||SQLERRM, v_params, 'return_meta_object_list', -1, -1, 3::int4);
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM;

END;





$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_query_to_check(sql_query text, is_array bool, explicit_fields bool)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	

DECLARE
    clean_query text;
    final_query text;
    has_with boolean;
    with_end_pos integer;
    select_pos integer;
    main_select text;
    cte_part text;
BEGIN
	
	
	
	


	
--  SELECT CASE WHEN substring(upper(ltrim(trim($a))) from 1 for 5)= 'WITH ' THEN 1 ELSE 0 END  FROM 	s_grnplm_as_cib_gm_mart_dg.hfact_max_load_date LIMIT 1
    -- Очищаем запрос от лишних пробелов в начале/конце
    clean_query := trim(sql_query);
   
    
    -- Проверяем, начинается ли запрос с WITH (учитывая возможные пробелы и комментарии)
    has_with := substring(upper(ltrim(clean_query)) from 1 for 4) = 'WITH';
     
   
    
    IF  NOT  has_with  THEN
        -- Простой случай: запрос без CTE
        final_query := format('
            WITH cte_ AS (','') ||clean_query ||FORMAT (')
            SELECT %s FROM cte_
			UNION ALL 
			SELECT  JSON_BUILD_OBJECT(''unit'', ''cnt'') AS record_identifier, count(*) AS v_value from cte_',       
        CASE 
            WHEN is_array THEN 'json_agg(row_to_json(cte_)) as record_identifier, 1 as v_value'
            WHEN explicit_fields THEN 'json_build_object() as record_identifier, 1 as v_value' -- нужно передать поля явно
            ELSE 'row_to_json(cte_) as record_identifier, 1 as v_value '
        END);
       final_query := REPLACE (final_query,'''''','''');
    ELSE
        -- Сложный случай: запрос уже содержит CTE
        -- Находим позицию SELECT после CTE
      select_pos :=  coalesce(
        (
            SELECT pos
            FROM generate_series(1, length(clean_query)) as pos
            WHERE substring(clean_query FROM pos) ~* '^\)[[:space:]]*select'
            ORDER BY pos DESC
            LIMIT 1
        ),
        0
    )+1 ;
        
        IF select_pos > 0 THEN
            -- Извлекаем CTE часть и основной SELECT
            cte_part := substring(clean_query from 1 for select_pos - 1);
            main_select := substring(clean_query from select_pos);
            -- Создаем запрос с оберткой
            final_query := rtrim(cte_part, ' ,')|| 
                ',
                cte_ AS ('||main_select||FORMAT(' )
                SELECT %s  FROM cte_
				UNION ALL 
				SELECT  JSON_BUILD_OBJECT(''unit'', ''cnt'') AS record_identifier, count(*) AS v_value from cte_',
            CASE 
                WHEN is_array THEN 'json_agg(row_to_json(cte_)) as record_identifier, 1 as v_value'
                ELSE 'row_to_json(cte_) as record_identifier , 1 as v_value'
            END)		;
           final_query := REPLACE (final_query,'''''','''');
        ELSE
            -- Если не нашли SELECT, возвращаем ошибку
            RAISE EXCEPTION 'Invalid query: no SELECT statement found';
        END IF;
    END IF;
    
    -- Выполняем запрос и возвращаем результат
    RETURN REPLACE (final_query::TEXT, '''','''''')::text ;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in query_to_json: % (Query: %)', SQLERRM, final_query;
END;






$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_batch_v2(p_etl_stage text, p_sch_src_id text, p_tbl_src_id text, p_attr_src_id text, p_wf_load_id int8, p_wf_id int8, p_period_run text, p_tbl_rstri_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
	
/* Описание параметров и их заполнения
 * Ежедневный запуск: таблица + DQ
 * p_wf_id      - ид загрузчика таблицы
 * p_wf_load_id - ид процесса загрузки таблицы
 * p_tbl_rstri_wf_load_id - фильтр на таблицу по объему проверяемых данных - указываем опционально
 *                        - проверочные скрипты должны учитывать наличие или отсутствие фильтра
 *                        - может совпадать с p_wf_load_id 
 *    
 * Периодический запуск: DQ в отдельном потоке
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * 2025-03-07 FVV v_test_templ - 0 - расчет данных, 1 - проверка шаблонов 
 * 2025-03-11 FVV Формирование и исполнение темповых таблиц для использования в основном скрипте проверки
 * 2025-04-25 FVV Расчет динамических интервалов в stat
 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_etl_stage = %I , p_sch_src_id = %I , p_tbl_src_id = %I , p_attr_src_id = %I , p_period_run = %I , p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_etl_stage
        , p_sch_src_id
        , p_tbl_src_id
        , p_attr_src_id
        , p_period_run
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );

    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
    BEGIN  -- !!
        
    DROP TABLE IF EXISTS temp_meta_error_event_stat;
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_error_event_stat';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Расчет статистики - лучше использовать готовую таблицу
    CREATE TEMPORARY TABLE temp_meta_error_event_stat
    AS     
    SELECT 
          m.screen_id,
          m.unit::TEXT,
          COALESCE(m.avg_moving_rec_error,0) - COALESCE(m.stddev_rec_error,0) AS min_inter,
          COALESCE(m.avg_moving_rec_error,0) + COALESCE(m.stddev_rec_error,0) AS max_inter
          FROM dg_full.vmeta_error_event_stat m
          WHERE 1 = 1 
            AND (m.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
            AND (m.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
    DISTRIBUTED BY (screen_id, unit);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_error_event_stat;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_error_event_stat - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_error_event_stat ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text , 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_error_event_stat '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;



    BEGIN 
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
--    ON COMMIT DROP
    AS
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.vmeta_object_ref_table AS o
            WHERE 1=1
              AND (o.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
              AND (o.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN 

   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   --ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              og.object_group_id
            , l.screen_id
            , l.etl_stage
            , og.object_group_type
            , st.screen_sql
            --!! , l.default_severity_score
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.period_run
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , l.exception_group_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_src_id ELSE NULL::int4 END AS priority_src_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_cd ELSE NULL::text END AS priority_cd
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_nm  ELSE NULL::text END AS priority_nm
            , p.priority_src_id  AS priority_src_id
            , p.priority_cd AS priority_cd
            , p.priority_nm      AS priority_nm
            , o.schema_src_id 
            , o.table_src_id 
        FROM dg_full.vmeta_screen_link AS l
        JOIN dg_full.vmeta_object_group_ref_table og 
        ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
              FROM dg_full.vmeta_object_ref_table o1
              WHERE 1=1
                AND (o1.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
                AND (o1.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
        ) o
        ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
        ON l.screen_template_id  = st.screen_template_id 
        JOIN dg_full.meta_priority_ref_table p 
        ON st.priority_cd = p.priority_cd
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
            AND (l.etl_stage  = p_etl_stage OR COALESCE(p_etl_stage,'') ='')
            AND COALESCE(l.period_run, 'ctl') like '%' || COALESCE(p_period_run, 'ctl') || '%' -- проверки по периодичности запуска: по-умолчанию уровень ctl
        )
       , tmp_sever AS ( -- общее кол-во проверок с весами
        SELECT 
           o.schema_src_id ,
           o.table_src_id ,
           o.screen_template_id ,
           max(o.priority_src_id) AS  severity,  -- общий вес проверки
           max(o.priority_src_id)::float4 / count(*)::float4 AS severity_cn -- вес каждой строки
           FROM tmp_st1 o
           WHERE 1=1
           GROUP BY 1, 2, 3
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.etl_stage
            , s1.object_group_type
            , s1.screen_sql
            , s2.severity_cn AS default_severity_score
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.period_run
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.exception_group_id
            , s1.priority_src_id AS severity
            , s1.priority_cd
            , s1.priority_nm
       FROM tmp_st1 s1
       LEFT JOIN tmp_sever s2 ON s1.schema_src_id = s2.schema_src_id AND s1.table_src_id = s2.table_src_id AND s1.screen_template_id = s2.screen_template_id 
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.etl_stage
            , l.object_group_type
            , l.screen_sql
            , l.default_severity_score
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.exception_group_id -- группа для определения исключения
--            , l.lower_board 
--            , l.upper_board 
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
--                AND (o.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
--                AND (o.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql,rec_ext.object_alias,'$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN 
                   v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
          ELSE      
                IF v_test_templ = 1 THEN
                   v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;

      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_error_event_fact;
            
                CREATE TEMPORARY TABLE temp_meta_error_event_fact AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN 0 
                           ELSE COALESCE(t.v_value,0) 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , rec.exception_group_id AS exception_group_id 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN 0 
                               ELSE round(COALESCE( (/* !!Умножаем в проверках 100 * */ t.v_value::numeric), 0 ), 4 )::float4 
                      END AS prc_from_to
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit  
                    , rec.default_severity_score AS default_severity_score
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , COALESCE(t.v_value,0) AS val_value
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , /*CASE WHEN ttt.val_type <> 'text' 
                            AND ttt.val_value BETWEEN stt.min_inter AND stt.max_inter
                            AND ttt.record_identifier::TEXT NOT LIKE '%unit%'
                           THEN 0::float8 -- не учитываем 
                           ELSE ttt.default_severity_score -- выставляем оценку
                      END*/ 
                     CASE 
                      WHEN ttt.record_identifier::TEXT LIKE '%unit%' 
                       AND ttt.val_type <> 'text'
                       AND (ttt.val_value < stt.min_inter OR ttt.val_value > stt.max_inter)
                      THEN  ttt.default_severity_score 
                      ELSE 0::float8 END AS final_severity_score     
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , CASE WHEN ttt.val_type = 'text' 
                           THEN ttt.val_value::TEXT 
                           ELSE 
                              -- По среднему отклонению
                              CASE WHEN ttt.val_value <  stt.min_inter THEN 'Ниже нижнего порога: ' || round (stt.min_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value >  stt.max_inter THEN 'Выше верхнего порога: ' || round (stt.max_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value BETWEEN stt.min_inter AND stt.max_inter THEN 'В диапазоне: ' || round (stt.min_inter::numeric,4)::TEXT || '-' || round (stt.max_inter::numeric,4)::TEXT
                              END  
                      END::text AS value
                    , e.exception_action_id AS exception_action_id 
                FROM ttt
                LEFT JOIN dg_full.meta_exception_action_ref_table e 
                       ON e.exception_group_id = ttt.exception_group_id 
                      AND ttt.prc_from_to BETWEEN e.prc_from AND COALESCE(e.prc_to,9999999999999)
                      -- !! AND t.record_identifier::text='{"unit" : "%"}'::TEXT
                LEFT JOIN temp_meta_error_event_stat stt 
                       ON stt.screen_id = ttt.screen_id
                      AND stt.unit::text =  ttt.json_unit 
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_error_event_fact;

                --   v_result := 1;
                INSERT INTO dg_full.meta_error_event_fact
                (
                    batch_id
                    , schema_src_id
                    , table_src_id
                    , screen_id
                    , event_time
                    , record_identifier
                    , final_severity_score
                    , record_error -- float8
                    , load_dttm
                    , wf_load_id
                    , src_cd
                    , wf_id
                    , check_sql
                    , metric
                    , key_metric
                    , value        -- TEXT
                    , exception_action_id
                )
                SELECT 
                      f.batch_id
                    , f.schema_src_id
                    , f.table_src_id
                    , f.screen_id
                    , f.event_time
                    , f.record_identifier
                    , f.final_severity_score
                    , f.record_error -- float8
                    , f.load_dttm
                    , f.wf_load_id
                    , f.src_cd
                    , f.wf_id
                    , f.check_sql
                    , f.metric
                    , f.key_metric
                    , f.value        -- TEXT
                    , f.exception_action_id
                FROM temp_meta_error_event_fact  f
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_error_event_fact' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_error_event_fact 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_error_event_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_error_event_fact 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    

--    ANALYZE dg_full.meta_error_event_fact;
--    RAISE NOTICE 'ANALYZE dg_full.meta_error_event_fact';
    RAISE NOTICE 'End loop';
   IF v_test_templ = 0 THEN -- запись реального результата --
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_batch'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_batch_fact';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
  END IF; -- запись реального результата --
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_batch'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;
    DROP TABLE IF EXISTS temp_meta_error_event_stat;

    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_batch'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;











$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_batch_v23(p_etl_stage text, p_sch_src_id text, p_tbl_src_id text, p_attr_src_id text, p_wf_load_id int8, p_wf_id int8, p_period_run text, p_tbl_rstri_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
    
    
    
    
    
/* Описание параметров и их заполнения
 * Ежедневный запуск: таблица + DQ
 * p_wf_id      - ид загрузчика таблицы
 * p_wf_load_id - ид процесса загрузки таблицы
 * p_tbl_rstri_wf_load_id - фильтр на таблицу по объему проверяемых данных - указываем опционально
 *                        - проверочные скрипты должны учитывать наличие или отсутствие фильтра
 *                        - может совпадать с p_wf_load_id 
 *    
 * Периодический запуск: DQ в отдельном потоке
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 *  
 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    v_start_dt       timestamp;
    v_cnt            int8;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_etl_stage = %I , p_sch_src_id = %I , p_tbl_src_id = %I , p_attr_src_id = %I , p_period_run = %I , p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_etl_stage
        , p_sch_src_id
        , p_tbl_src_id
        , p_attr_src_id
        , p_period_run
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );
       
    v_batch_id := nextval('dg_full.synth_key_seq');
    v_start_dt := CURRENT_TIMESTAMP; 
    
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.meta_object_ref_table AS o
            WHERE 1=1
              AND (o.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
              AND (o.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
            ORDER BY o.object_group_id
                   , o.object_order
            DISTRIBUTED REPLICATED;       
GET DIAGNOSTICS v_cnt = row_count;
--ANALYZE temp_meta_object_ref_table;
--v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
--RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
-- trace regime
--INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
---VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
SELECT clock_timestamp() INTO v_interval_fr;
    CREATE TEMPORARY TABLE temp_meta_screen_link
    ON COMMIT DROP
    AS
        SELECT
              og.object_group_id
            , l.screen_id
            , l.etl_stage
            , og.object_group_type
            , st.screen_sql
            , l.default_severity_score
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.period_run
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , l.exception_group_id
        FROM dg_full.meta_screen_link AS l
        JOIN dg_full.meta_object_group_ref_table og 
        ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT o1.object_group_id, o1.schema_src_id, o1.table_src_id 
              FROM dg_full.meta_object_ref_table o1
              WHERE 1=1
                AND (o1.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
                AND (o1.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
        ) o
        ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
        ON l.screen_template_id  = st.screen_template_id 
        WHERE 1=1
            AND l.is_active = 1
            AND (l.etl_stage  = p_etl_stage OR COALESCE(p_etl_stage,'') ='')
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
            AND COALESCE(l.period_run, 'ctl') like '%' || COALESCE(p_period_run, 'ctl') || '%' -- проверки по периодичности запуска: по-умолчанию уровень ctl
        DISTRIBUTED BY (screen_id);       
GET DIAGNOSTICS v_cnt = row_count;
--ANALYZE temp_meta_screen_link;
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
--RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
-- trace regime
--INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
-- ( 'temp_meta_screen_link ' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.etl_stage
            , l.object_group_type
            , l.screen_sql
            , l.default_severity_score
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.exception_group_id -- группа для определения исключения
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP 
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
--                AND (o.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
--                AND (o.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql,rec_ext.object_alias,'$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias,coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id));
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP;
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          --RAISE NOTICE 'Start: screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          --SELECT clock_timestamp() INTO v_interval_fr;
         -- v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP 
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11 ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                     -- RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                     -- INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      --VALUES ( 'loop step 12 ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP;
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2 '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21 ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                 -- RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                 -- INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                 -- VALUES ( 'loop step 22 ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                   -- RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP;
          END IF ;

            LOOP
               BEGIN 
                --   v_result := 1;
                INSERT INTO dg_full.meta_error_event_fact
                (
                    batch_id
                    , schema_src_id
                    , table_src_id
                    , screen_id
                    , event_time
                    , record_identifier
                    , final_severity_score
                    , record_error -- float8
                    , load_dttm
                    , wf_load_id
                    , src_cd
                    , wf_id
                    , check_sql
                    , metric
                    , key_metric
                    , value        -- TEXT
                    , exception_action_id
                )
                SELECT
                      v_batch_id
                    , v_sch_src_id
                    , v_tbl_src_id
                    , rec.screen_id
                    , 0::INTEGER
                    , t.record_identifier 
                    , rec.default_severity_score
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN 0 ELSE COALESCE(t.v_value,0) END::float8 AS record_error 
                    , clock_timestamp()
                    , p_wf_load_id
                    , rec.src_cd
                    , p_wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN COALESCE(t.v_value,0)::text ELSE '00' END::text AS value
                    , e.exception_action_id AS exception_action_id 
                FROM temp_out_tbl t
                LEFT JOIN dg_full.meta_exception_action_ref_table e ON e.exception_group_id = rec.exception_group_id 
                         AND CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN 0 ELSE 100 * COALESCE(t.v_value,0) END::float8 BETWEEN e.prc_from AND e.prc_to
                         AND t.record_identifier::text='{"unit" : "%"}'::text
                ;
            
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_error_event_fact' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
               -- RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_error_event_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
               --   RAISE NOTICE '40P01: INSERT INTO dg_full.meta_error_event_fact';
                WHEN OTHERS THEN
                    -- trace regime
                 --   INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                --    VALUES ( 'meta_error_event_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                 --   RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP;
        ELSE
        --  RAISE NOTICE 'Start: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP
    ;
--    ANALYZE dg_full.meta_error_event_fact;
--    RAISE NOTICE 'ANALYZE dg_full.meta_error_event_fact';
   -- RAISE NOTICE 'End loop';
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_batch'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
              --  RAISE NOTICE 'INSERT INTO dg_full.meta_batch_fact';
                -- trace regime
               -- INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
               -- VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                 -- INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                 -- VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                --  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                   -- INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                   -- VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
    -- trace regime
   -- INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
   -- VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_batch'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            --RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_batch'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;






$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_batch_v2_20251024(p_etl_stage text, p_sch_src_id text, p_tbl_src_id text, p_attr_src_id text, p_wf_load_id int8, p_wf_id int8, p_period_run text, p_tbl_rstri_wf_load_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
    
    
    
    
    
    
    
    
    
    
    
    
/* Описание параметров и их заполнения
 * Ежедневный запуск: таблица + DQ
 * p_wf_id      - ид загрузчика таблицы
 * p_wf_load_id - ид процесса загрузки таблицы
 * p_tbl_rstri_wf_load_id - фильтр на таблицу по объему проверяемых данных - указываем опционально
 *                        - проверочные скрипты должны учитывать наличие или отсутствие фильтра
 *                        - может совпадать с p_wf_load_id 
 *    
 * Периодический запуск: DQ в отдельном потоке
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * 2025-03-07 FVV v_test_templ - 0 - расчет данных, 1 - проверка шаблонов 
 * 2025-03-11 FVV Формирование и исполнение темповых таблиц для использования в основном скрипте проверки
 * 2025-04-25 FVV Расчет динамических интервалов в stat
 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_etl_stage = %I , p_sch_src_id = %I , p_tbl_src_id = %I , p_attr_src_id = %I , p_period_run = %I , p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_etl_stage
        , p_sch_src_id
        , p_tbl_src_id
        , p_attr_src_id
        , p_period_run
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );

    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
    BEGIN  -- !!
        
    DROP TABLE IF EXISTS temp_meta_error_event_stat;
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_error_event_stat';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Расчет статистики - лучше использовать готовую таблицу
    CREATE TEMPORARY TABLE temp_meta_error_event_stat
    AS     
    SELECT 
          m.screen_id,
          m.unit::TEXT,
          COALESCE(m.avg_moving_rec_error,0) - COALESCE(m.stddev_rec_error,0) AS min_inter,
          COALESCE(m.avg_moving_rec_error,0) + COALESCE(m.stddev_rec_error,0) AS max_inter
          FROM s_grnplm_as_cib_gm_dg.vmeta_error_event_stat m
          WHERE 1 = 1 
            AND (m.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
            AND (m.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
    DISTRIBUTED BY (screen_id, unit);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_error_event_stat;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_error_event_stat - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_error_event_stat ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text , 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_error_event_stat '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;



    BEGIN 
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    --ON COMMIT DROP
    AS
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM s_grnplm_as_cib_gm_dg.vmeta_object_ref_table AS o
            WHERE 1=1
              AND (o.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
              AND (o.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN 

   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
--   ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              og.object_group_id
            , l.screen_id
            , l.etl_stage
            , og.object_group_type
            , st.screen_sql
            --!! , l.default_severity_score
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.period_run
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , l.exception_group_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_src_id ELSE NULL::int4 END AS priority_src_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_cd ELSE NULL::text END AS priority_cd
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_nm  ELSE NULL::text END AS priority_nm
            , p.priority_src_id  AS priority_src_id
            , p.priority_cd AS priority_cd
            , p.priority_nm      AS priority_nm
            , o.schema_src_id 
            , o.table_src_id 
        FROM s_grnplm_as_cib_gm_dg.vmeta_screen_link AS l
        JOIN s_grnplm_as_cib_gm_dg.vmeta_object_group_ref_table og 
        ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
              FROM s_grnplm_as_cib_gm_dg.vmeta_object_ref_table o1
              WHERE 1=1
                AND (o1.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
                AND (o1.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
        ) o
        ON o.object_group_id  = og.object_group_id
        JOIN s_grnplm_as_cib_gm_dg.meta_screen_template_ref_table AS st 
        ON l.screen_template_id  = st.screen_template_id 
        JOIN s_grnplm_as_cib_gm_dg.meta_priority_ref_table p 
        ON st.priority_cd = p.priority_cd
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
            AND (l.etl_stage  = p_etl_stage OR COALESCE(p_etl_stage,'') ='')
            AND COALESCE(l.period_run, 'ctl') like '%' || COALESCE(p_period_run, 'ctl') || '%' -- проверки по периодичности запуска: по-умолчанию уровень ctl
        )
       , tmp_sever AS ( -- общее кол-во проверок с весами
        SELECT 
           o.schema_src_id ,
           o.table_src_id ,
           o.screen_template_id ,
           max(o.priority_src_id) AS  severity,  -- общий вес проверки
           max(o.priority_src_id)::float4 / count(*)::float4 AS severity_cn -- вес каждой строки
           FROM tmp_st1 o
           WHERE 1=1
           GROUP BY 1, 2, 3
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.etl_stage
            , s1.object_group_type
            , s1.screen_sql
            , s2.severity_cn AS default_severity_score
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.period_run
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.exception_group_id
            , s1.priority_src_id AS severity
            , s1.priority_cd
            , s1.priority_nm
       FROM tmp_st1 s1
       LEFT JOIN tmp_sever s2 ON s1.schema_src_id = s2.schema_src_id AND s1.table_src_id = s2.table_src_id AND s1.screen_template_id = s2.screen_template_id 
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.etl_stage
            , l.object_group_type
            , l.screen_sql
            , l.default_severity_score
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.exception_group_id -- группа для определения исключения
--            , l.lower_board 
--            , l.upper_board 
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
--                AND (o.schema_src_id  = p_sch_src_id OR COALESCE(p_sch_src_id,'') ='')
--                AND (o.table_src_id = p_tbl_src_id OR COALESCE(p_tbl_src_id,'') ='')
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql,rec_ext.object_alias,'$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN 
                   v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
          ELSE      
                IF v_test_templ = 1 THEN
                   v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;

      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_error_event_fact;
            
                CREATE TEMPORARY TABLE temp_meta_error_event_fact AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN 0 
                           ELSE COALESCE(t.v_value,0) 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , rec.exception_group_id AS exception_group_id 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN 0 
                               ELSE round(COALESCE( (/* !!Умножаем в проверках 100 * */ t.v_value::numeric), 0 ), 4 )::float4 
                      END AS prc_from_to
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit  
                    , rec.default_severity_score AS default_severity_score
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , COALESCE(t.v_value,0) AS val_value
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , /*CASE WHEN ttt.val_type <> 'text' 
                            AND ttt.val_value BETWEEN stt.min_inter AND stt.max_inter
                            AND ttt.record_identifier::TEXT NOT LIKE '%unit%'
                           THEN 0::float8 -- не учитываем 
                           ELSE ttt.default_severity_score -- выставляем оценку
                      END*/ 
                     CASE 
                      WHEN ttt.record_identifier::TEXT LIKE '%unit%' 
                       AND ttt.val_type <> 'text'
                       AND (ttt.val_value < stt.min_inter OR ttt.val_value > stt.max_inter)
                      THEN  ttt.default_severity_score 
                      ELSE 0::float8 END AS final_severity_score     
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , CASE WHEN ttt.val_type = 'text' 
                           THEN ttt.val_value::TEXT 
                           ELSE 
                              -- По среднему отклонению
                              CASE WHEN ttt.val_value <  stt.min_inter THEN 'Ниже нижнего порога: ' || round (stt.min_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value >  stt.max_inter THEN 'Выше верхнего порога: ' || round (stt.max_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value BETWEEN stt.min_inter AND stt.max_inter THEN 'В диапазоне: ' || round (stt.min_inter::numeric,4)::TEXT || '-' || round (stt.max_inter::numeric,4)::TEXT
                              END  
                      END::text AS value
                    , e.exception_action_id AS exception_action_id 
                FROM ttt
                LEFT JOIN s_grnplm_as_cib_gm_dg.meta_exception_action_ref_table e 
                       ON e.exception_group_id = ttt.exception_group_id 
                      AND ttt.prc_from_to BETWEEN e.prc_from AND COALESCE(e.prc_to,9999999999999)
                      -- !! AND t.record_identifier::text='{"unit" : "%"}'::TEXT
                LEFT JOIN temp_meta_error_event_stat stt 
                       ON stt.screen_id = ttt.screen_id
                      AND stt.unit::text =  ttt.json_unit 
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_error_event_fact;

                --   v_result := 1;
                INSERT INTO dg_full.meta_error_event_fact
                (
                    batch_id
                    , schema_src_id
                    , table_src_id
                    , screen_id
                    , event_time
                    , record_identifier
                    , final_severity_score
                    , record_error -- float8
                    , load_dttm
                    , wf_load_id
                    , src_cd
                    , wf_id
                    , check_sql
                    , metric
                    , key_metric
                    , value        -- TEXT
                    , exception_action_id
                )
                SELECT 
                      f.batch_id
                    , f.schema_src_id
                    , f.table_src_id
                    , f.screen_id
                    , f.event_time
                    , f.record_identifier
                    , f.final_severity_score
                    , f.record_error -- float8
                    , f.load_dttm
                    , f.wf_load_id
                    , f.src_cd
                    , f.wf_id
                    , f.check_sql
                    , f.metric
                    , f.key_metric
                    , f.value        -- TEXT
                    , f.exception_action_id
                FROM temp_meta_error_event_fact  f
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_error_event_fact' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_error_event_fact 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO s_grnplm_as_cib_gm_dg.meta_error_event_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_error_event_fact 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов: %', rec.screen_id, rec.object_group_id, rec.screen_template_id, v_sql;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    

--    ANALYZE s_grnplm_as_cib_gm_dg.meta_error_event_fact;
--    RAISE NOTICE 'ANALYZE s_grnplm_as_cib_gm_dg.meta_error_event_fact';
    RAISE NOTICE 'End loop';
   IF v_test_templ = 0 THEN -- запись реального результата --
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_batch'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO s_grnplm_as_cib_gm_dg.meta_batch_fact';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO s_grnplm_as_cib_gm_dg.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
  END IF; -- запись реального результата --
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_batch'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;
    DROP TABLE IF EXISTS temp_meta_error_event_stat;

    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_batch'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_batch_v3(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
    
    
    
    
/* Описание параметров и их заполнения
 * Ежедневный запуск: таблица + DQ
 * p_wf_id      - ид загрузчика таблицы
 * p_wf_load_id - ид процесса загрузки таблицы
 * p_tbl_rstri_wf_load_id - фильтр на таблицу по объему проверяемых данных - указываем опционально
 *                        - проверочные скрипты должны учитывать наличие или отсутствие фильтра
 *                        - может совпадать с p_wf_load_id 
 *    
 * Периодический запуск: DQ в отдельном потоке
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * 2025-03-07 FVV v_test_templ - 0 - расчет данных, 1 - проверка шаблонов 
 * 2025-03-11 FVV Формирование и исполнение темповых таблиц для использования в основном скрипте проверки
 * 2025-04-25 FVV Расчет динамических интервалов в stat
 * 2025-06-27 FVV Кастомизация для проверки вью в витринах
 * p_etl_stage text,  задаем дефолтом
 * p_period_run text, задаем дефолтом

 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_etl_stage      TEXT := 'dm';
    p_period_run     TEXT := 'view';
    p_sch_src_id     TEXT := '';
    p_tbl_src_id     TEXT := '';
    p_attr_src_id    TEXT := '';
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_etl_stage = %I , p_sch_src_id = %I , p_tbl_src_id = %I , p_attr_src_id = %I , p_period_run = %I , p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_etl_stage
        , p_sch_src_id
        , p_tbl_src_id
        , p_attr_src_id
        , p_period_run
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );

    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
BEGIN 
DROP TABLE IF EXISTS temp_view_loader;    
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_view_loader';
SELECT clock_timestamp() INTO v_interval_fr;
--- Какие вью готовы к проверке ------------
CREATE TEMPORARY TABLE temp_view_loader AS 
WITH dt AS (
         SELECT now() AS now_
        )
        , wino AS (
         SELECT DISTINCT
            olink.node_id, -- состав вью
            olink.node_src_id,
            olink.schema_src_id,
            olink.node_type_cd,
            olink.src_cd,
            olink.depth,
            olink.root_node_id, -- проверяемая вью
            olink.root_node_src_id,
            olink.root_schema_src_id,
            olink.root_node_type_cd,
            o.tbl_type,
            o.max_dttm,
            o.max_eff_from_dttm,
            o.max_eff_to_dttm,
            now() - o.max_dttm::timestamp with time zone AS date_diff,
            sh.plan_ AS sh_plan_,
            sh.plan_next AS sh_plan_next,
            sh.plan_dt AS sh_plan_dt,
            CASE
                    WHEN now()::date = sh.plan_dt AND olink.schema_src_id !~~ '%_stg_%'::text AND olink.schema_src_id !~~ '%_espd_%'::text AND olink.schema_src_id !~~ '%_udlprod'::text THEN 1
                    ELSE 0
            END AS fl_stg
           FROM s_grnplm_as_cib_gm_mart_dg.meta_search_graph_target_all_obj olink
             LEFT JOIN dg_full.vmeta_execute_fact o ON olink.node_src_id = o.tbl_name AND olink.schema_src_id = o.sch_name AND o.max_dttm::date = now()::date
             LEFT JOIN s_grnplm_as_cib_gm_dg.meta_scheduler_plan sh ON olink.node_src_id = sh.node_src_id AND olink.schema_src_id = sh.schema_src_id AND sh.plan_::date >= COALESCE(o.max_eff_from_dttm::date, now()::date) AND sh.plan_::date <= COALESCE(o.max_eff_to_dttm::date, now()::date)
          WHERE 1 = 1 
            AND olink.root_node_type_cd::text = 'View'::TEXT -- для вьюх
            AND olink.node_type_cd::text = 'Table'::text     -- проверяем таблицы
        )
        , link AS (
         SELECT 
            wino.node_id,
            wino.schema_src_id,
            wino.node_src_id,
            wino.tbl_type,
            wino.node_type_cd,
            wino.src_cd,
            wino.depth,
            min(wino.depth) OVER (PARTITION BY wino.root_node_id) AS min_depth,
            wino.max_dttm,
            wino.max_eff_from_dttm,
            wino.max_eff_to_dttm,
            wino.date_diff,
            wino.root_node_id,
            wino.root_schema_src_id,
            wino.root_node_src_id,
            wino.root_node_type_cd,
            wino.max_eff_from_dttm AS fact_started,
            wino.max_eff_to_dttm AS fact_ended,
            (max(wino.sh_plan_) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone AS plan_dt,
            (max(wino.sh_plan_next) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone - '00:00:01'::INTERVAL AS plan_next_dt,
            wino.fl_stg--,
            --wino.severity,
            --wino.severity_max
           FROM wino
        )
        , link_0 AS (
         SELECT 
            l.schema_src_id,
            l.node_src_id,
            l.node_type_cd,
            l.depth,
            l.min_depth,
            l.root_schema_src_id,
            l.root_node_src_id,
            l.root_node_type_cd,
            CASE
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth THEN l.fact_ended
                    ELSE NULL::timestamp without time zone
            END AS fact_ended,
            l.plan_dt,
            CASE
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth AND l.fact_ended > now() THEN 0
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth AND l.fact_ended >= l.plan_dt::date::timestamp without time zone AND l.fact_ended <= now() THEN 1
                    ELSE NULL::integer
            END AS fl_fact_today,
            CASE
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth THEN 1
                    ELSE NULL::integer
            END AS fl_waited_today--,
            --l.severity,
            --l.severity_max
           FROM link l
        )
        , st_1 AS (
         SELECT DISTINCT w1.root_schema_src_id,
            w1.root_node_src_id,
            w1.root_node_type_cd,
            max(w1.fact_ended) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w1,
            sum(w1.fl_waited_today) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w2,
            sum(w1.fl_fact_today) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w3
           FROM link_0 w1
        )
SELECT * FROM (        
 SELECT 
    s1.root_schema_src_id,
    s1.root_node_src_id,
    s1.w1 AS root_max_dttm,
    CASE WHEN s1.w2 = s1.w3 THEN s1.w1
    ELSE NULL::timestamp without time zone
    END AS ready_max_dttm,
    CASE WHEN CASE WHEN s1.w2 = s1.w3 THEN s1.w1 ELSE NULL::timestamp without time zone END BETWEEN now() - '1 hour'::interval AND now() THEN 1::int4 -- проверка за каждый час готовых вьюх
         WHEN CASE WHEN s1.w2 = s1.w3 THEN s1.w1 ELSE NULL::timestamp without time zone END IS NULL 
          AND now()::time BETWEEN '23:00:00'::time AND '23:59:59'::time THEN 2::int4 
    ELSE NULL::int4       
    END AS load_flg
   FROM st_1 s1
  WHERE 1 = 1 
    AND s1.root_schema_src_id ~~ '%_as_cib_gm_%'::text 
    AND (s1.root_schema_src_id <> ALL (ARRAY['s_grnplm_as_cib_gm_mart_dg'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_stg_espd'::text]))
    -- !! AND CASE WHEN s1.w2 = s1.w3 THEN s1.w1 ELSE NULL::timestamp without time zone END BETWEEN now() - '1 hour'::interval AND now()
 ) tt
 WHERE 1=1
   AND tt.load_flg IN (1,2)
 DISTRIBUTED BY (root_schema_src_id, root_node_src_id);
  
  GET DIAGNOSTICS v_cnt = row_count;
  ANALYZE temp_view_loader;
  v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
  RAISE NOTICE 'temp_view_loader - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
  -- trace regime
  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
  VALUES ( 'temp_view_loader ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

  EXCEPTION
    
  WHEN OTHERS THEN
  -- trace regime
  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
  VALUES ( 'temp_view_loader '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
  RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
  RETURN -1;
  END;


---------------------------------------
    BEGIN  -- !!
    DROP TABLE IF EXISTS temp_meta_error_event_stat;
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_error_event_stat';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Расчет статистики - лучше использовать готовую таблицу
    CREATE TEMPORARY TABLE temp_meta_error_event_stat
    AS     
    SELECT 
          m.screen_id,
          m.unit::TEXT,
          COALESCE(m.avg_moving_rec_error,0) - COALESCE(m.stddev_rec_error,0) AS min_inter,
          COALESCE(m.avg_moving_rec_error,0) + COALESCE(m.stddev_rec_error,0) AS max_inter
          FROM s_grnplm_as_cib_gm_dg.meta_error_event_stat m
          JOIN temp_view_loader v ON m.schema_src_id = v.root_schema_src_id AND m.table_src_id = v.root_node_src_id  -- только готовые за час
          WHERE 1 = 1 
    DISTRIBUTED BY (screen_id, unit);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_error_event_stat;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_error_event_stat - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_error_event_stat ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text , 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_error_event_stat '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;
---------------------------------------  
  
    BEGIN 
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.vmeta_object_ref_table AS o
            JOIN temp_view_loader v ON o.schema_src_id = v.root_schema_src_id AND o.table_src_id = v.root_node_src_id  -- только готовые за час
            WHERE 1=1
            --ORDER BY o.object_group_id , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN 
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_o AS (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
                   FROM dg_full.vmeta_object_ref_table o1
                   JOIN temp_view_loader v ON o1.schema_src_id = v.root_schema_src_id AND o1.table_src_id = v.root_node_src_id  -- только готовые за час
                   WHERE 1=1
    ) 
    , tmp_st1 AS (
        SELECT
              og.object_group_id
            , l.screen_id
            , l.etl_stage
            , og.object_group_type
            , st.screen_sql
            --!! , l.default_severity_score
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.period_run
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , l.exception_group_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_src_id ELSE NULL::int4 END AS priority_src_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_cd ELSE NULL::text END AS priority_cd
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_nm  ELSE NULL::text END AS priority_nm
            , p.priority_src_id  AS priority_src_id
            , p.priority_cd AS priority_cd
            , p.priority_nm      AS priority_nm
            , o.schema_src_id 
            , o.table_src_id 
        FROM dg_full.vmeta_screen_link AS l
        JOIN dg_full.vmeta_object_group_ref_table og 
        ON l.object_group_id  = og.object_group_id
        JOIN tmp_o o
        ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
        ON l.screen_template_id  = st.screen_template_id 
        JOIN dg_full.meta_priority_ref_table p 
        ON st.priority_cd = p.priority_cd
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
            AND (l.etl_stage  = p_etl_stage OR COALESCE(p_etl_stage,'') ='')
            AND COALESCE(l.period_run, 'ctl') like '%' || COALESCE(p_period_run, 'ctl') || '%' -- проверки по периодичности запуска: по-умолчанию уровень ctl
        )
       , tmp_sever AS ( -- общее кол-во проверок с весами
        SELECT 
           o.schema_src_id ,
           o.table_src_id ,
           o.screen_template_id ,
           max(o.priority_src_id) AS  severity,  -- общий вес проверки
           max(o.priority_src_id)::float4 / count(*)::float4 AS severity_cn -- вес каждой строки
           FROM tmp_st1 o
           WHERE 1=1
           GROUP BY 1, 2, 3
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.etl_stage
            , s1.object_group_type
            , s1.screen_sql
            , s2.severity_cn AS default_severity_score
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.period_run
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.exception_group_id
            , s1.priority_src_id AS severity
            , s1.priority_cd
            , s1.priority_nm
       FROM tmp_st1 s1
       JOIN temp_view_loader l ON s1.schema_src_id = l.root_schema_src_id AND s1.table_src_id = l.root_node_src_id  -- только завершенные объекты
       LEFT JOIN tmp_sever s2 ON s1.schema_src_id = s2.schema_src_id AND s1.table_src_id = s2.table_src_id AND s1.screen_template_id = s2.screen_template_id 
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

----------------------------------------------------------------------------------    

    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.etl_stage
            , l.object_group_type
            , l.screen_sql
            , l.default_severity_score
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.exception_group_id -- группа для определения исключения
--            , l.lower_board 
--            , l.upper_board 
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql,rec_ext.object_alias,'$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN 
                   v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
          ELSE      
                IF v_test_templ = 1 THEN
                   v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;

      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_error_event_fact;
            
                CREATE TEMPORARY TABLE temp_meta_error_event_fact AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN 0 
                           ELSE COALESCE(t.v_value,0) 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , rec.exception_group_id AS exception_group_id 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN 0 
                               ELSE round(COALESCE( (/* !!Умножаем в проверках 100 * */ t.v_value::numeric), 0 ), 4 )::float4 
                      END AS prc_from_to
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit  
                    , rec.default_severity_score AS default_severity_score
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , COALESCE(t.v_value,0) AS val_value
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , /*CASE WHEN ttt.val_type <> 'text' 
                            AND ttt.val_value BETWEEN stt.min_inter AND stt.max_inter
                            AND ttt.record_identifier::TEXT NOT LIKE '%unit%'
                           THEN 0::float8 -- не учитываем 
                           ELSE ttt.default_severity_score -- выставляем оценку
                      END*/ 
                     CASE 
                      WHEN ttt.record_identifier::TEXT LIKE '%unit%' 
                       AND ttt.val_type <> 'text'
                       AND (ttt.val_value < stt.min_inter OR ttt.val_value > stt.max_inter)
                      THEN  ttt.default_severity_score 
                      ELSE 0::float8 END AS final_severity_score     
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , CASE WHEN ttt.val_type = 'text' 
                           THEN ttt.val_value::TEXT 
                           ELSE 
                              -- По среднему отклонению
                              CASE WHEN ttt.val_value <  stt.min_inter THEN 'Ниже нижнего порога: ' || round (stt.min_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value >  stt.max_inter THEN 'Выше верхнего порога: ' || round (stt.max_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value BETWEEN stt.min_inter AND stt.max_inter THEN 'В диапазоне: ' || round (stt.min_inter::numeric,4)::TEXT || '-' || round (stt.max_inter::numeric,4)::TEXT
                              END  
                      END::text AS value
                    , e.exception_action_id AS exception_action_id 
                FROM ttt
                LEFT JOIN dg_full.meta_exception_action_ref_table e 
                       ON e.exception_group_id = ttt.exception_group_id 
                      AND ttt.prc_from_to BETWEEN e.prc_from AND COALESCE(e.prc_to,9999999999999)
                      -- !! AND t.record_identifier::text='{"unit" : "%"}'::TEXT
                LEFT JOIN temp_meta_error_event_stat stt 
                       ON stt.screen_id = ttt.screen_id
                      AND stt.unit::text =  ttt.json_unit 
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_error_event_fact;

                --   v_result := 1;
                INSERT INTO dg_full.meta_error_event_fact
                (
                    batch_id
                    , schema_src_id
                    , table_src_id
                    , screen_id
                    , event_time
                    , record_identifier
                    , final_severity_score
                    , record_error -- float8
                    , load_dttm
                    , wf_load_id
                    , src_cd
                    , wf_id
                    , check_sql
                    , metric
                    , key_metric
                    , value        -- TEXT
                    , exception_action_id
                )
                SELECT 
                      f.batch_id
                    , f.schema_src_id
                    , f.table_src_id
                    , f.screen_id
                    , f.event_time
                    , f.record_identifier
                    , f.final_severity_score
                    , f.record_error -- float8
                    , f.load_dttm
                    , f.wf_load_id
                    , f.src_cd
                    , f.wf_id
                    , f.check_sql
                    , f.metric
                    , f.key_metric
                    , f.value        -- TEXT
                    , f.exception_action_id
                FROM temp_meta_error_event_fact  f
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_error_event_fact' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_error_event_fact 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_error_event_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_error_event_fact 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % ,v_sql = % , Нарушение замены алиасов.', 
                        rec.screen_id, rec.object_group_id, rec.screen_template_id, v_sql;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    
    DROP TABLE IF EXISTS temp_meta_error_event_stat;

--    ANALYZE dg_full.meta_error_event_fact;
--    RAISE NOTICE 'ANALYZE dg_full.meta_error_event_fact';
    RAISE NOTICE 'End loop';
   IF v_test_templ = 0 THEN -- запись реального результата --
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_batch_view'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_batch_fact';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
  END IF; -- запись реального результата --
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_batch_view'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_batch_view'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;









$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_batch_v3(p_category text, p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
    
    
    
    
/* Описание параметров и их заполнения
 * Ежедневный запуск: таблица + DQ
 * p_wf_id      - ид загрузчика таблицы
 * p_wf_load_id - ид процесса загрузки таблицы
 * p_tbl_rstri_wf_load_id - фильтр на таблицу по объему проверяемых данных - указываем опционально
 *                        - проверочные скрипты должны учитывать наличие или отсутствие фильтра
 *                        - может совпадать с p_wf_load_id 
 *    
 * Периодический запуск: DQ в отдельном потоке
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * 2025-03-07 FVV v_test_templ - 0 - расчет данных, 1 - проверка шаблонов 
 * 2025-03-11 FVV Формирование и исполнение темповых таблиц для использования в основном скрипте проверки
 * 2025-04-25 FVV Расчет динамических интервалов в stat
 * 2025-06-27 FVV Кастомизация для проверки вью в витринах
 * p_etl_stage text,  задаем дефолтом
 * p_period_run text, задаем дефолтом
 * p_category text, категория проверяемых объектов - r1 или все остальные 

 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_etl_stage      TEXT := 'dm';
    p_period_run     TEXT := 'view';
    p_sch_src_id     TEXT := '';
    p_tbl_src_id     TEXT := '';
    p_attr_src_id    TEXT := '';
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_etl_stage = %I , p_sch_src_id = %I , p_tbl_src_id = %I , p_attr_src_id = %I , p_period_run = %I , p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_etl_stage
        , p_sch_src_id
        , p_tbl_src_id
        , p_attr_src_id
        , p_period_run
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );

    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
BEGIN 
DROP TABLE IF EXISTS temp_view_loader;    
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_view_loader';
SELECT clock_timestamp() INTO v_interval_fr;
--- Какие вью готовы к проверке ------------
CREATE TEMPORARY TABLE temp_view_loader AS 
WITH dt AS (
         SELECT now() AS now_
        )
        , wino AS (
         SELECT DISTINCT
            olink.node_id, -- состав вью
            olink.node_src_id,
            olink.schema_src_id,
            olink.node_type_cd,
            olink.src_cd,
            olink.depth,
            olink.root_node_id, -- проверяемая вью
            olink.root_node_src_id,
            olink.root_schema_src_id,
            olink.root_node_type_cd,
            o.tbl_type,
            o.max_dttm,
            o.max_eff_from_dttm,
            o.max_eff_to_dttm,
            now() - o.max_dttm::timestamp with time zone AS date_diff,
            sh.plan_ AS sh_plan_,
            sh.plan_next AS sh_plan_next,
            sh.plan_dt AS sh_plan_dt,
            CASE
                    WHEN now()::date = sh.plan_dt AND olink.schema_src_id !~~ '%_stg_%'::text AND olink.schema_src_id !~~ '%_espd_%'::text AND olink.schema_src_id !~~ '%_udlprod'::text THEN 1
                    ELSE 0
            END AS fl_stg
           FROM s_grnplm_as_cib_gm_mart_dg.meta_search_graph_target_all_obj olink
             LEFT JOIN dg_full.vmeta_execute_fact o ON olink.node_src_id = o.tbl_name AND olink.schema_src_id = o.sch_name AND o.max_dttm::date = now()::date
             LEFT JOIN s_grnplm_as_cib_gm_dg.meta_scheduler_plan sh ON olink.node_src_id = sh.node_src_id AND olink.schema_src_id = sh.schema_src_id AND sh.plan_::date >= COALESCE(o.max_eff_from_dttm::date, now()::date) AND sh.plan_::date <= COALESCE(o.max_eff_to_dttm::date, now()::date)
          WHERE 1 = 1 
            AND olink.root_node_type_cd::text = 'View'::TEXT -- для вьюх
            AND olink.node_type_cd::text = 'Table'::text     -- проверяем таблицы
        )
        , link AS (
         SELECT 
            wino.node_id,
            wino.schema_src_id,
            wino.node_src_id,
            wino.tbl_type,
            wino.node_type_cd,
            wino.src_cd,
            wino.depth,
            min(wino.depth) OVER (PARTITION BY wino.root_node_id) AS min_depth,
            wino.max_dttm,
            wino.max_eff_from_dttm,
            wino.max_eff_to_dttm,
            wino.date_diff,
            wino.root_node_id,
            wino.root_schema_src_id,
            wino.root_node_src_id,
            wino.root_node_type_cd,
            wino.max_eff_from_dttm AS fact_started,
            wino.max_eff_to_dttm AS fact_ended,
            (max(wino.sh_plan_) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone AS plan_dt,
            (max(wino.sh_plan_next) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone - '00:00:01'::INTERVAL AS plan_next_dt,
            wino.fl_stg--,
            --wino.severity,
            --wino.severity_max
           FROM wino
        )
        , link_0 AS (
         SELECT 
            l.schema_src_id,
            l.node_src_id,
            l.node_type_cd,
            l.depth,
            l.min_depth,
            l.root_schema_src_id,
            l.root_node_src_id,
            l.root_node_type_cd,
            CASE
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth THEN l.fact_ended
                    ELSE NULL::timestamp without time zone
            END AS fact_ended,
            l.plan_dt,
            CASE
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth AND l.fact_ended > now() THEN 0
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth AND l.fact_ended >= l.plan_dt::date::timestamp without time zone AND l.fact_ended <= now() THEN 1
                    ELSE NULL::integer
            END AS fl_fact_today,
            CASE
                    WHEN l.fl_stg = 1 AND l.depth = l.min_depth THEN 1
                    ELSE NULL::integer
            END AS fl_waited_today--,
            --l.severity,
            --l.severity_max
           FROM link l
        )
        , st_1 AS (
         SELECT DISTINCT w1.root_schema_src_id,
            w1.root_node_src_id,
            w1.root_node_type_cd,
            max(w1.fact_ended) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w1,
            sum(w1.fl_waited_today) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w2,
            sum(w1.fl_fact_today) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w3
           FROM link_0 w1
        )
SELECT * FROM (        
 SELECT 
    s1.root_schema_src_id,
    s1.root_node_src_id,
    s1.w1 AS root_max_dttm,
    CASE WHEN s1.w2 = s1.w3 THEN s1.w1
    ELSE NULL::timestamp without time zone
    END AS ready_max_dttm,
    CASE WHEN CASE WHEN s1.w2 = s1.w3 THEN s1.w1 ELSE NULL::timestamp without time zone END BETWEEN now() - '1 hour'::interval AND now() THEN 1::int4 -- проверка за каждый час готовых вьюх
         WHEN CASE WHEN s1.w2 = s1.w3 THEN s1.w1 ELSE NULL::timestamp without time zone END IS NULL 
          AND now()::time BETWEEN '23:00:00'::time AND '23:59:59'::time THEN 2::int4 
    ELSE NULL::int4       
    END AS load_flg,
    CASE WHEN p_category = 'r1' AND s1.root_schema_src_id LIKE '%_r1_%' THEN 1
         WHEN p_category = 'r1' AND s1.root_schema_src_id NOT LIKE '%_r1_%' THEN 0
         WHEN p_category <> 'r1' AND s1.root_schema_src_id LIKE '%_r1_%' THEN 0
         WHEN p_category <> 'r1' AND s1.root_schema_src_id NOT LIKE '%_r1_%' THEN 1
         ELSE NULL
    END::int4 AS r1_flg
   FROM st_1 s1
  WHERE 1 = 1 
    AND s1.root_schema_src_id ~~ '%_as_cib_gm_%'::text 
    AND (s1.root_schema_src_id <> ALL (ARRAY['s_grnplm_as_cib_gm_mart_dg'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_stg_espd'::text]))
    -- !! AND CASE WHEN s1.w2 = s1.w3 THEN s1.w1 ELSE NULL::timestamp without time zone END BETWEEN now() - '1 hour'::interval AND now()
 ) tt
 WHERE 1=1
   AND tt.load_flg IN (1,2)
   AND tt.r1_flg = 1
 DISTRIBUTED BY (root_schema_src_id, root_node_src_id);
  
  GET DIAGNOSTICS v_cnt = row_count;
  ANALYZE temp_view_loader;
  v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
  RAISE NOTICE 'temp_view_loader - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
  -- trace regime
  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
  VALUES ( 'temp_view_loader ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

  EXCEPTION
    
  WHEN OTHERS THEN
  -- trace regime
  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
  VALUES ( 'temp_view_loader '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
  RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
  RETURN -1;
  END;


---------------------------------------
    BEGIN  -- !!
    DROP TABLE IF EXISTS temp_meta_error_event_stat;
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_error_event_stat';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Расчет статистики - лучше использовать готовую таблицу
    CREATE TEMPORARY TABLE temp_meta_error_event_stat
    AS     
    SELECT 
          m.screen_id,
          m.unit::TEXT,
          COALESCE(m.avg_moving_rec_error,0) - COALESCE(m.stddev_rec_error,0) AS min_inter,
          COALESCE(m.avg_moving_rec_error,0) + COALESCE(m.stddev_rec_error,0) AS max_inter
          FROM s_grnplm_as_cib_gm_dg.meta_error_event_stat m
          JOIN temp_view_loader v ON m.schema_src_id = v.root_schema_src_id AND m.table_src_id = v.root_node_src_id  -- только готовые за час
          WHERE 1 = 1 
    DISTRIBUTED BY (screen_id, unit);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_error_event_stat;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_error_event_stat - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_error_event_stat ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text , 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_error_event_stat '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;
---------------------------------------  
  
    BEGIN 
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.vmeta_object_ref_table AS o
            JOIN temp_view_loader v ON o.schema_src_id = v.root_schema_src_id AND o.table_src_id = v.root_node_src_id  -- только готовые за час
            WHERE 1=1
            --ORDER BY o.object_group_id , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN 
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_o AS (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
                   FROM dg_full.vmeta_object_ref_table o1
                   JOIN temp_view_loader v ON o1.schema_src_id = v.root_schema_src_id AND o1.table_src_id = v.root_node_src_id  -- только готовые за час
                   WHERE 1=1
    ) 
    , tmp_st1 AS (
        SELECT
              og.object_group_id
            , l.screen_id
            , l.etl_stage
            , og.object_group_type
            , st.screen_sql
            --!! , l.default_severity_score
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.period_run
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , l.exception_group_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_src_id ELSE NULL::int4 END AS priority_src_id
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_cd ELSE NULL::text END AS priority_cd
            -- !! , CASE WHEN l.screen_template_id IN (/*10011, 11, 10002, 2 ,10003, 3, 10004, 4, */ 13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73) THEN p.priority_nm  ELSE NULL::text END AS priority_nm
            , p.priority_src_id  AS priority_src_id
            , p.priority_cd AS priority_cd
            , p.priority_nm      AS priority_nm
            , o.schema_src_id 
            , o.table_src_id 
        FROM dg_full.vmeta_screen_link AS l
        JOIN dg_full.vmeta_object_group_ref_table og 
        ON l.object_group_id  = og.object_group_id
        JOIN tmp_o o
        ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
        ON l.screen_template_id  = st.screen_template_id 
        JOIN dg_full.meta_priority_ref_table p 
        ON st.priority_cd = p.priority_cd
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
            AND (l.etl_stage  = p_etl_stage OR COALESCE(p_etl_stage,'') ='')
            AND COALESCE(l.period_run, 'ctl') like '%' || COALESCE(p_period_run, 'ctl') || '%' -- проверки по периодичности запуска: по-умолчанию уровень ctl
        )
       , tmp_sever AS ( -- общее кол-во проверок с весами
        SELECT 
           o.schema_src_id ,
           o.table_src_id ,
           o.screen_template_id ,
           max(o.priority_src_id) AS  severity,  -- общий вес проверки
           max(o.priority_src_id)::float4 / count(*)::float4 AS severity_cn -- вес каждой строки
           FROM tmp_st1 o
           WHERE 1=1
           GROUP BY 1, 2, 3
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.etl_stage
            , s1.object_group_type
            , s1.screen_sql
            , s2.severity_cn AS default_severity_score
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.period_run
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.exception_group_id
            , s1.priority_src_id AS severity
            , s1.priority_cd
            , s1.priority_nm
       FROM tmp_st1 s1
       JOIN temp_view_loader l ON s1.schema_src_id = l.root_schema_src_id AND s1.table_src_id = l.root_node_src_id  -- только завершенные объекты
       LEFT JOIN tmp_sever s2 ON s1.schema_src_id = s2.schema_src_id AND s1.table_src_id = s2.table_src_id AND s1.screen_template_id = s2.screen_template_id 
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

----------------------------------------------------------------------------------    

    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.etl_stage
            , l.object_group_type
            , l.screen_sql
            , l.default_severity_score
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.exception_group_id -- группа для определения исключения
--            , l.lower_board 
--            , l.upper_board 
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql,rec_ext.object_alias,'$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN 
                   v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
          ELSE      
                IF v_test_templ = 1 THEN
                   v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;

      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_error_event_fact;
            
                CREATE TEMPORARY TABLE temp_meta_error_event_fact AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN 0 
                           ELSE COALESCE(t.v_value,0) 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , rec.exception_group_id AS exception_group_id 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' THEN 0 
                               ELSE round(COALESCE( (/* !!Умножаем в проверках 100 * */ t.v_value::numeric), 0 ), 4 )::float4 
                      END AS prc_from_to
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit  
                    , rec.default_severity_score AS default_severity_score
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , COALESCE(t.v_value,0) AS val_value
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , /*CASE WHEN ttt.val_type <> 'text' 
                            AND ttt.val_value BETWEEN stt.min_inter AND stt.max_inter
                            AND ttt.record_identifier::TEXT NOT LIKE '%unit%'
                           THEN 0::float8 -- не учитываем 
                           ELSE ttt.default_severity_score -- выставляем оценку
                      END*/ 
                     CASE 
                      WHEN ttt.record_identifier::TEXT LIKE '%unit%' 
                       AND ttt.val_type <> 'text'
                       AND (ttt.val_value < stt.min_inter OR ttt.val_value > stt.max_inter)
                      THEN  ttt.default_severity_score 
                      ELSE 0::float8 END AS final_severity_score     
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , CASE WHEN ttt.val_type = 'text' 
                           THEN ttt.val_value::TEXT 
                           ELSE 
                              -- По среднему отклонению
                              CASE WHEN ttt.val_value <  stt.min_inter THEN 'Ниже нижнего порога: ' || round (stt.min_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value >  stt.max_inter THEN 'Выше верхнего порога: ' || round (stt.max_inter::numeric,4)::TEXT
                                   WHEN ttt.val_value BETWEEN stt.min_inter AND stt.max_inter THEN 'В диапазоне: ' || round (stt.min_inter::numeric,4)::TEXT || '-' || round (stt.max_inter::numeric,4)::TEXT
                              END  
                      END::text AS value
                    , e.exception_action_id AS exception_action_id 
                FROM ttt
                LEFT JOIN dg_full.meta_exception_action_ref_table e 
                       ON e.exception_group_id = ttt.exception_group_id 
                      AND ttt.prc_from_to BETWEEN e.prc_from AND COALESCE(e.prc_to,9999999999999)
                      -- !! AND t.record_identifier::text='{"unit" : "%"}'::TEXT
                LEFT JOIN temp_meta_error_event_stat stt 
                       ON stt.screen_id = ttt.screen_id
                      AND stt.unit::text =  ttt.json_unit 
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_error_event_fact;

                --   v_result := 1;
                INSERT INTO dg_full.meta_error_event_fact
                (
                    batch_id
                    , schema_src_id
                    , table_src_id
                    , screen_id
                    , event_time
                    , record_identifier
                    , final_severity_score
                    , record_error -- float8
                    , load_dttm
                    , wf_load_id
                    , src_cd
                    , wf_id
                    , check_sql
                    , metric
                    , key_metric
                    , value        -- TEXT
                    , exception_action_id
                )
                SELECT 
                      f.batch_id
                    , f.schema_src_id
                    , f.table_src_id
                    , f.screen_id
                    , f.event_time
                    , f.record_identifier
                    , f.final_severity_score
                    , f.record_error -- float8
                    , f.load_dttm
                    , f.wf_load_id
                    , f.src_cd
                    , f.wf_id
                    , f.check_sql
                    , f.metric
                    , f.key_metric
                    , f.value        -- TEXT
                    , f.exception_action_id
                FROM temp_meta_error_event_fact  f
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_error_event_fact' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_error_event_fact 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_error_event_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_error_event_fact 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % ,v_sql = % , Нарушение замены алиасов.', 
                        rec.screen_id, rec.object_group_id, rec.screen_template_id, v_sql;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    
    DROP TABLE IF EXISTS temp_meta_error_event_stat;

--    ANALYZE dg_full.meta_error_event_fact;
--    RAISE NOTICE 'ANALYZE dg_full.meta_error_event_fact';
    RAISE NOTICE 'End loop';
   IF v_test_templ = 0 THEN -- запись реального результата --
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_batch_view'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_batch_fact';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_batch_view'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
  END IF; -- запись реального результата --
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_batch_view'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_batch_view', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_batch_view'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;










$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_signal(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
    
/* Описание параметров и их заполнения
 * Периодический запуск: в сервисе рассылки
 * Проверяем наличие сигналов для рассылки
 * Формируем текст письма
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    rec_m            record;
    v_sql_m          TEXT := '';
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );
    -- При задании значения < -1, проводим провеку коректности  скриптов
    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
    BEGIN 
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT DISTINCT 
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.vmeta_object_ref_table AS o
            JOIN dg_full.meta_signal_link sl ON o.object_group_id = sl.object_group_id 
            WHERE 1=1
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN 
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              l.object_group_id
            , l.signal_id AS  screen_id
            , og.object_group_type
            , st.screen_sql
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , o.schema_src_id 
            , o.table_src_id 
            , l.attached_screen_id AS attached_screen_id -- attached
            , l.html_screen_id AS html_screen_id -- html
        FROM dg_full.meta_signal_link AS l
        JOIN dg_full.vmeta_object_group_ref_table og 
          ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
              FROM dg_full.vmeta_object_ref_table o1
              WHERE 1=1
             ) o
          ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
          ON l.screen_template_id  = st.screen_template_id 
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.object_group_type
            , s1.screen_sql
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.attached_screen_id -- attached
            , s1.html_screen_id -- html
       FROM tmp_st1 s1
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
        WHEN OTHERS THEN
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
        RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
        RETURN -1;
    END;

    -- Подготовка вложений в письмо при необходимости
    BEGIN
       v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_attached';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_attached
   ON COMMIT DROP
   AS
        WITH jsn AS 
        (SELECT 
            f.screen_id, json_agg(f.record_identifier) AS json_text 
        FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
        JOIN (SELECT screen_id, max(batch_id) AS m_batch_id FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact GROUP BY screen_id) m ON f.screen_id = m.screen_id AND f.batch_id = m.m_batch_id
        GROUP BY f.screen_id
        )
        SELECT 
        s.signal_id,
        s.attached_screen_id AS attached_screen_id,
        f1.json_text AS attached_json_text,
        s.html_screen_id AS html_screen_id, 
        f2.json_text AS html_json_text
        FROM dg_full.meta_signal_link s
        LEFT JOIN jsn f1 ON s.attached_screen_id = f1.screen_id 
        LEFT JOIN jsn f2 ON s.html_screen_id = f2.screen_id 
        DISTRIBUTED BY (signal_id);       
        GET DIAGNOSTICS v_cnt = row_count;
        ANALYZE temp_meta_attached;
        v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
        RAISE NOTICE 'temp_meta_attached - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'temp_meta_attached ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    EXCEPTION
        WHEN OTHERS THEN
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'temp_meta_attached '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
        RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
        RETURN -1;
    END;
    
    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.object_group_type
            , l.screen_sql
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.attached_screen_id 
            , l.html_screen_id
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql, rec_ext.object_alias, '$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %, attached_id = %, html_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id, rec.attached_screen_id , rec.html_screen_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN            
                 IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN 
                     v_sql:=  v_sql || ';  ';
                    ELSE 
                     v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
                END IF ;
          ELSE      
                IF v_test_templ = 1 THEN
                    IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN RAISE NOTICE 'cant be analyzed';
                        ELSE 
                        v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                    END IF ;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::TEXT || ' , attached_screen_id = ' || rec.attached_screen_id::text || ' , html_screen_id = ' ||  rec.html_screen_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;
          RAISE NOTICE '%',v_sql;
      
      
      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_run_signal;
                CREATE TEMPORARY TABLE temp_meta_run_signal AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN NULL 
                           ELSE t.v_value 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit 
                    ---lgi--------------------------------------------------
                    , (t.record_identifier::jsonb ->> 'table_html')::TEXT AS json_table
                    -----------------------------------------------------------
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN t.v_value 
                           ELSE  NULL
                      END::text AS val_value 
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , ttt.val_value AS value
                    ---lgi------------
                    , ttt.json_table
                    --------------
                FROM ttt
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_run_signal;
               RAISE NOTICE 'temp_meta_run_signal - %', v_cnt::TEXT;

               -- Добавление текста письма
               DROP TABLE IF EXISTS temp_meta_email_template;
               -- Использование функции в запросе
               CREATE TEMPORARY TABLE temp_meta_email_template AS 
               WITH template_data AS (
                     SELECT 
                          f.batch_id,
                          f.load_dttm,
                          f.wf_load_id,
                          f.src_cd,
                          f.wf_id,
                          f.schema_src_id, 
                          f.table_src_id, 
                          f.screen_id, 
                          m.email_template_title, 
                          m.email_template_body, 
                          m."type",
                          f.record_identifier,
                          l.email_recipient_id,
                          l.attached_screen_id ,
                          l.html_screen_id ,
                          --------lgi-----------
                          f.json_table 
                          -------------------
               FROM 
                      temp_meta_run_signal f
               JOIN dg_full.meta_signal_link l 
                 ON f.screen_id = l.signal_id 
               JOIN dg_full.meta_email_template_ref_table m 
                 ON l.email_template_id = m.email_template_id 
                AND m.email_template_id = f.record_error::int8 
               )
               SELECT
                p.batch_id,
                p.load_dttm,
                p.wf_load_id,
                p.src_cd,
                p.wf_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
           --    p.email_template_body as original_template,
                ----------------------lgi----------------------------
                dg_full.meta_apply_all_replacements(p.email_template_body, p.record_identifier::jsonb, p.json_table::jsonb) as processed_template,
                -------------------------------------------------------------------------------------------
                p.TYPE,
                r.email_recipient_cd ,
                p.attached_screen_id ,
                p.html_screen_id , 
                a1.attached_json_text AS proccesed_attached ,
                a2.html_json_text AS proccesed_html
                FROM template_data p
                JOIN dg_full.meta_email_recipient_ref_table r ON p.email_recipient_id = r.email_recipient_id  
                LEFT JOIN temp_meta_attached a1 ON a1.attached_screen_id = p.attached_screen_id
                LEFT JOIN temp_meta_attached a2 ON a2.html_screen_id = p.html_screen_id
                DISTRIBUTED BY (schema_src_id, table_src_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_email_template;
               RAISE NOTICE 'temp_meta_email_template - %', v_cnt::TEXT;

                --   v_result := 1;
                INSERT INTO dg_full.meta_run_signal -- meta_error_event_fact
                (
                    batch_id,              -- ID Пакета
                    schema_src_id,         -- ID системы-источника\схемы
                    table_src_id,          -- ID объекта с источника
                    screen_id,             -- Шаблон
                    email_template_title,  -- Заголовок
                    processed_template,    -- Добавление в Тело письма
                    proccesed_attached,    -- Добавление приложение к письму 
                    type,                  -- Тип
                    email_recipient_cd,    -- Получатели
                    load_dttm,             -- Дата и время загрузки
                    wf_load_id,            -- Идентификатор загрузки
                    wf_id                  -- Идентификатор потока
                )
                SELECT 
                p.batch_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
                p.processed_template,
                p.proccesed_attached,    -- Добавление приложение к письму 
                p.TYPE,
                p.email_recipient_cd, 
                p.load_dttm,
                p.wf_load_id,
                p.wf_id
                FROM temp_meta_email_template  p
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_run_signal' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_run_signal 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_run_signal';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_run_signal 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    
--    ANALYZE dg_full.meta_run_signal;
--    RAISE NOTICE 'ANALYZE dg_full.meta_run_signal';
    RAISE NOTICE 'End loop';

    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_signal'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_run_signal';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;


    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_signal'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;
    DROP TABLE IF EXISTS temp_meta_run_signal;
    DROP TABLE IF EXISTS temp_meta_email_template;
    DROP TABLE IF EXISTS temp_meta_attached;

    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_signal'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;




















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_signal_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
    
    
    
    
/* Описание параметров и их заполнения
 * Периодический запуск: в сервисе рассылки
 * Проверяем наличие сигналов для рассылки
 * Формируем текст письма
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    rec_m            record;
    v_sql_m          TEXT := '';
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );
    -- При задании значения < -1, проводим провеку коректности  скриптов
    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
    BEGIN 
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT DISTINCT 
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.vmeta_object_ref_table AS o
            JOIN dg_full.meta_signal_link sl ON o.object_group_id = sl.object_group_id 
            WHERE 1=1
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN 
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              l.object_group_id
            , l.signal_id AS  screen_id
            , og.object_group_type
            , st.screen_sql
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , o.schema_src_id 
            , o.table_src_id 
        FROM dg_full.meta_signal_link AS l
        JOIN dg_full.vmeta_object_group_ref_table og 
          ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
              FROM dg_full.vmeta_object_ref_table o1
              WHERE 1=1
             ) o
          ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
          ON l.screen_template_id  = st.screen_template_id 
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.object_group_type
            , s1.screen_sql
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
       FROM tmp_st1 s1
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.object_group_type
            , l.screen_sql
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql, rec_ext.object_alias, '$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN            
        		 IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN 
        			 v_sql:=  v_sql || ';  ';
        			ELSE 
         			 v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
         		END IF ;
          ELSE      
                IF v_test_templ = 1 THEN
                	IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN RAISE NOTICE 'cant be analyzed';
                		ELSE 
                   		v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                 	END IF ;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;
          RAISE NOTICE 'end';
      
      
      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_run_signal;
                CREATE TEMPORARY TABLE temp_meta_run_signal AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN NULL 
                           ELSE t.v_value 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit 
                    ---lgi--------------------------------------------------
                    , (t.record_identifier::jsonb ->> 'table_html')::TEXT AS json_table
                    -----------------------------------------------------------
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN t.v_value 
                           ELSE  NULL
                      END::text AS val_value 
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , ttt.val_value AS value
                    ---lgi------------
                    , ttt.json_table
                    --------------
                FROM ttt
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_run_signal;

               -- Добавление текста письма
               DROP TABLE IF EXISTS temp_meta_email_template;
               -- Использование функции в запросе
               CREATE TEMPORARY TABLE temp_meta_email_template AS 
               WITH template_data AS (
                     SELECT 
                          f.batch_id,
                          f.load_dttm,
                          f.wf_load_id,
                          f.src_cd,
                          f.wf_id,
                          f.schema_src_id, 
                          f.table_src_id, 
                          f.screen_id, 
                          m.email_template_title, 
                          m.email_template_body, 
                          m."type",
                          f.record_identifier,
                          l.email_recipient_id,
                          --------lgi-----------
                          f.json_table 
                          -------------------
               FROM 
                      temp_meta_run_signal f
               JOIN dg_full.meta_signal_link l 
                 ON f.screen_id = l.signal_id 
               JOIN dg_full.meta_email_template_ref_table m 
                 ON l.email_template_id = m.email_template_id 
                AND m.email_template_id = f.record_error::int8 
               )
               SELECT
                p.batch_id,
                p.load_dttm,
                p.wf_load_id,
                p.src_cd,
                p.wf_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
           --    p.email_template_body as original_template,
                ----------------------lgi----------------------------
                dg_full.meta_apply_all_replacements(p.email_template_body, p.record_identifier::jsonb, p.json_table::jsonb) as processed_template,
                -------------------------------------------------------------------------------------------
                p.TYPE,
                r.email_recipient_cd 
                FROM template_data p
                JOIN dg_full.meta_email_recipient_ref_table r ON p.email_recipient_id = r.email_recipient_id  
                DISTRIBUTED BY (schema_src_id, table_src_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_email_template;
               
                --   v_result := 1;
                INSERT INTO dg_full.meta_run_signal -- meta_error_event_fact
                (
                    batch_id,              -- ID Пакета
                    schema_src_id,         -- ID системы-источника\схемы
                    table_src_id,          -- ID объекта с источника
                    screen_id,             -- Шаблон
                    email_template_title,  -- Заголовок
                    processed_template, -- Тело письма
                    type,               -- Тип
                    email_recipient_cd, -- Получатели
                    load_dttm,          -- Дата и время загрузки
                    wf_load_id,         -- Идентификатор загрузки
                    wf_id               -- Идентификатор потока
                )
                SELECT 
                p.batch_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
                p.processed_template,
                p.TYPE,
                p.email_recipient_cd, 
                p.load_dttm,
                p.wf_load_id,
                p.wf_id
                FROM temp_meta_email_template  p
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_run_signal' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_run_signal 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_run_signal';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_run_signal 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    
--    ANALYZE dg_full.meta_run_signal;
--    RAISE NOTICE 'ANALYZE dg_full.meta_run_signal';
    RAISE NOTICE 'End loop';
   IF v_test_templ = 0 THEN -- запись реального результата --
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_signal'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_run_signal';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
  END IF; -- запись реального результата --
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_signal'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;

    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_signal'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;










$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_signal_prom(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
    
    
    
    
    

/* Описание параметров и их заполнения
 * Периодический запуск: в сервисе рассылки
 * Проверяем наличие сигналов для рассылки
 * Формируем текст письма
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * */

DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := '';
    v_tbl_src_id     TEXT := '';
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    rec_m            record;
    v_sql_m          TEXT := '';
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );
    -- При задании значения < -1, проводим провеку коректности  скриптов
    IF p_wf_id < -1::int8 THEN
         v_test_templ := 1; --
    ELSE v_test_templ := 0;
    END IF;


    IF v_test_templ = 0 THEN
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;

    v_start_dt := CURRENT_TIMESTAMP;

    BEGIN
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT DISTINCT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM s_grnplm_as_cib_gm_dg.vmeta_object_ref_table AS o
            JOIN s_grnplm_as_cib_gm_dg.meta_signal_link sl ON o.object_group_id = sl.object_group_id
            WHERE 1=1
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION

    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              l.object_group_id
            , l.signal_id AS  screen_id
            , og.object_group_type
            , st.screen_sql
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , o.schema_src_id
            , o.table_src_id
            , l.attached_screen_id AS attached_screen_id -- attached
            , l.html_screen_id AS html_screen_id -- html
        FROM s_grnplm_as_cib_gm_dg.meta_signal_link AS l
        JOIN s_grnplm_as_cib_gm_dg.vmeta_object_group_ref_table og
          ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id
              FROM s_grnplm_as_cib_gm_dg.vmeta_object_ref_table o1
              WHERE 1=1
             ) o
          ON o.object_group_id  = og.object_group_id
        JOIN s_grnplm_as_cib_gm_dg.meta_screen_template_ref_table AS st
          ON l.screen_template_id  = st.screen_template_id
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.object_group_type
            , s1.screen_sql
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.attached_screen_id -- attached
            , s1.html_screen_id -- html
       FROM tmp_st1 s1
    DISTRIBUTED BY (screen_id);
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
        WHEN OTHERS THEN
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

        RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
        RETURN -1;
    END;

    -- Подготовка вложений в письмо при необходимости
    BEGIN
       v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_attached';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_attached
   ON COMMIT DROP
   AS
        WITH jsn AS
        (SELECT
            f.screen_id, json_agg(f.record_identifier) AS json_text
        FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
        JOIN (SELECT screen_id, max(batch_id) AS m_batch_id FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact GROUP BY screen_id) m ON f.screen_id = m.screen_id AND f.batch_id = m.m_batch_id
        GROUP BY f.screen_id
        )
        SELECT
        s.signal_id,
        s.attached_screen_id AS attached_screen_id,
        f1.json_text AS attached_json_text,
        s.html_screen_id AS html_screen_id,
        f2.json_text AS html_json_text
        FROM s_grnplm_as_cib_gm_dg.meta_signal_link s
        LEFT JOIN jsn f1 ON s.attached_screen_id = f1.screen_id
        LEFT JOIN jsn f2 ON s.html_screen_id = f2.screen_id
        DISTRIBUTED BY (signal_id);
        GET DIAGNOSTICS v_cnt = row_count;
        ANALYZE temp_meta_attached;
        v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
        RAISE NOTICE 'temp_meta_attached - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'temp_meta_attached ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    EXCEPTION
        WHEN OTHERS THEN
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'temp_meta_attached '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

        RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
        RETURN -1;
    END;

    FOR rec IN
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.object_group_type
            , l.screen_sql
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.attached_screen_id
            , l.html_screen_id
        FROM temp_meta_screen_link l
        ORDER BY     l.screen_id, l.object_group_id
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql, rec_ext.object_alias, '$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = ''
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF;
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %, attached_id = %, html_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id, rec.attached_screen_id , rec.html_screen_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;

          IF v_test_templ = 0 THEN
                 IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN
                     v_sql:=  v_sql || ';  ';
                    ELSE
                     v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
                END IF ;
          ELSE
                IF v_test_templ = 1 THEN
                    IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN RAISE NOTICE 'cant be analyzed';
                        ELSE
                        v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                    END IF ;
                END IF;
          END IF;

          IF v_using = '' THEN
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM dg_full.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::TEXT || ' , attached_screen_id = ' || rec.attached_screen_id::text || ' , html_screen_id = ' ||  rec.html_screen_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                WHEN SQLSTATE '40P01' THEN
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM dg_full.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;
          RAISE NOTICE '%',v_sql;


      IF v_test_templ = 0 THEN  -- условие записи реального результата
            LOOP -- начало - цикл записи результата --
               BEGIN
                DROP TABLE IF EXISTS temp_meta_run_signal;
                CREATE TEMPORARY TABLE temp_meta_run_signal AS
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text'
                           THEN NULL
                           ELSE t.v_value
                      END::float8 AS record_error
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit
                    ---lgi--------------------------------------------------
                    , (t.record_identifier::jsonb ->> 'table_html')::TEXT AS json_table
                    -----------------------------------------------------------
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text'
                           THEN t.v_value
                           ELSE  NULL
                      END::text AS val_value
                FROM temp_out_tbl t
                )
                SELECT
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier
                    , ttt.record_error
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql
                    , ttt.metric
                    , ttt.key_metric
                    , ttt.val_value AS value
                    ---lgi------------
                    , ttt.json_table
                    --------------
                FROM ttt
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_run_signal;
               RAISE NOTICE 'temp_meta_run_signal - %', v_cnt::TEXT;

               -- Добавление текста письма
               DROP TABLE IF EXISTS temp_meta_email_template;
               -- Использование функции в запросе
               CREATE TEMPORARY TABLE temp_meta_email_template AS
               WITH template_data AS (
                     SELECT
                          f.batch_id,
                          f.load_dttm,
                          f.wf_load_id,
                          f.src_cd,
                          f.wf_id,
                          f.schema_src_id,
                          f.table_src_id,
                          f.screen_id,
                          m.email_template_title,
                          m.email_template_body,
                          m."type",
                          f.record_identifier,
                          l.email_recipient_id,
                          l.attached_screen_id ,
                          l.html_screen_id ,
                          --------lgi-----------
                          f.json_table
                          -------------------
               FROM
                      temp_meta_run_signal f
               JOIN s_grnplm_as_cib_gm_dg.meta_signal_link l
                 ON f.screen_id = l.signal_id
               JOIN s_grnplm_as_cib_gm_dg.meta_email_template_ref_table m
                 ON l.email_template_id = m.email_template_id
                AND m.email_template_id = f.record_error::int8
               )
               SELECT
                p.batch_id,
                p.load_dttm,
                p.wf_load_id,
                p.src_cd,
                p.wf_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
           --    p.email_template_body as original_template,
                ----------------------lgi----------------------------
                s_grnplm_as_cib_gm_dg.meta_apply_all_replacements(p.email_template_body, p.record_identifier::jsonb, p.json_table::jsonb) as processed_template,
                -------------------------------------------------------------------------------------------
                p.TYPE,
                r.email_recipient_cd ,
                p.attached_screen_id ,
                p.html_screen_id ,
                a1.attached_json_text AS proccesed_attached ,
                a2.html_json_text AS proccesed_html
                FROM template_data p
                JOIN s_grnplm_as_cib_gm_dg.meta_email_recipient_ref_table r ON p.email_recipient_id = r.email_recipient_id
                LEFT JOIN temp_meta_attached a1 ON a1.attached_screen_id = p.attached_screen_id
                LEFT JOIN temp_meta_attached a2 ON a2.html_screen_id = p.html_screen_id
                DISTRIBUTED BY (schema_src_id, table_src_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_email_template;
               RAISE NOTICE 'temp_meta_email_template - %', v_cnt::TEXT;

                --   v_result := 1;
                INSERT INTO dg_full.meta_run_signal -- meta_error_event_fact
                (
                    batch_id,              -- ID Пакета
                    schema_src_id,         -- ID системы-источника\схемы
                    table_src_id,          -- ID объекта с источника
                    screen_id,             -- Шаблон
                    email_template_title,  -- Заголовок
                    processed_template,    -- Добавление в Тело письма
                    proccesed_attached,    -- Добавление приложение к письму
                    type,                  -- Тип
                    email_recipient_cd,    -- Получатели
                    load_dttm,             -- Дата и время загрузки
                    wf_load_id,            -- Идентификатор загрузки
                    wf_id                  -- Идентификатор потока
                )
                SELECT
                p.batch_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
                p.processed_template,
                p.proccesed_attached,    -- Добавление приложение к письму
                p.TYPE,
                p.email_recipient_cd,
                p.load_dttm,
                p.wf_load_id,
                p.wf_id
                FROM temp_meta_email_template  p
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_run_signal' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION
                WHEN SQLSTATE '40P01' THEN
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_run_signal 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_run_signal';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_run_signal 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM dg_full.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата --
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------

--    ANALYZE s_grnplm_as_cib_gm_dg.meta_run_signal;
--    RAISE NOTICE 'ANALYZE s_grnplm_as_cib_gm_dg.meta_run_signal';
    RAISE NOTICE 'End loop';

    LOOP
            BEGIN
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_signal'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_run_signal';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION
                WHEN SQLSTATE '40P01' THEN
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM dg_full.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;


    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM dg_full.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_signal'
            , p_wf_load_id
            , p_wf_id
            , 0::int4
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;
    DROP TABLE IF EXISTS temp_meta_run_signal;
    DROP TABLE IF EXISTS temp_meta_email_template;
    DROP TABLE IF EXISTS temp_meta_attached;

    RETURN v_batch_id;


    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM dg_full.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_signal'
                , p_wf_load_id
                , p_wf_id
                , 3::int4
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;






















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_signal_tst(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	

/* Описание параметров и их заполнения
 * Периодический запуск: в сервисе рассылки
 * Проверяем наличие сигналов для рассылки
 * Формируем текст письма
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * */

DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := '';
    v_tbl_src_id     TEXT := '';
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    rec_m            record;
    v_sql_m          TEXT := '';
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );
    -- При задании значения < -1, проводим провеку коректности  скриптов
    IF p_wf_id < -1::int8 THEN
         v_test_templ := 1; --
    ELSE v_test_templ := 0;
    END IF;


    IF v_test_templ = 0 THEN
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;

    v_start_dt := CURRENT_TIMESTAMP;

    BEGIN
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT DISTINCT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM s_grnplm_as_cib_gm_dg.vmeta_object_ref_table AS o
            JOIN s_grnplm_as_cib_gm_dg.meta_signal_link sl ON o.object_group_id = sl.object_group_id
            WHERE 1=1
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
 

    EXCEPTION

    WHEN OTHERS THEN
    -- trace regime
  

    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -1;
    END;

   BEGIN
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              l.object_group_id
            , l.signal_id AS  screen_id
            , og.object_group_type
            , st.screen_sql
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , o.schema_src_id
            , o.table_src_id
            , l.attached_screen_id AS attached_screen_id -- attached
            , l.html_screen_id AS html_screen_id -- html
        FROM s_grnplm_as_cib_gm_dg.meta_signal_link AS l
        JOIN s_grnplm_as_cib_gm_dg.vmeta_object_group_ref_table og
          ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id
              FROM s_grnplm_as_cib_gm_dg.vmeta_object_ref_table o1
              WHERE 1=1
             ) o
          ON o.object_group_id  = og.object_group_id
        JOIN s_grnplm_as_cib_gm_dg.meta_screen_template_ref_table AS st
          ON l.screen_template_id  = st.screen_template_id
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.object_group_type
            , s1.screen_sql
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
            , s1.attached_screen_id -- attached
            , s1.html_screen_id -- html
       FROM tmp_st1 s1
    DISTRIBUTED BY (screen_id);
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    

    EXCEPTION
        WHEN OTHERS THEN
        -- trace regime
       

        RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
        RETURN -2;
    END;

    -- Подготовка вложений в письмо при необходимости
    BEGIN
       v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_attached';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_attached
   ON COMMIT DROP
   AS
        WITH jsn AS
        (SELECT
            f.screen_id, json_agg(f.record_identifier) AS json_text
        FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
        JOIN (SELECT screen_id, max(batch_id) AS m_batch_id FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact GROUP BY screen_id) m ON f.screen_id = m.screen_id AND f.batch_id = m.m_batch_id
        GROUP BY f.screen_id
        )
        SELECT
        s.signal_id,
        s.attached_screen_id AS attached_screen_id,
        f1.json_text AS attached_json_text,
        s.html_screen_id AS html_screen_id,
        f2.json_text AS html_json_text
        FROM s_grnplm_as_cib_gm_dg.meta_signal_link s
        LEFT JOIN jsn f1 ON s.attached_screen_id = f1.screen_id
        LEFT JOIN jsn f2 ON s.html_screen_id = f2.screen_id
        DISTRIBUTED BY (signal_id);
        GET DIAGNOSTICS v_cnt = row_count;
        ANALYZE temp_meta_attached;
        v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
        RAISE NOTICE 'temp_meta_attached - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
        -- trace regime   
        EXCEPTION
       WHEN OTHERS THEN
        -- trace regime
        RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
        RETURN -3;
    END;

    FOR rec IN
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.object_group_type
            , l.screen_sql
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
            , l.attached_screen_id
            , l.html_screen_id
        FROM temp_meta_screen_link l
        ORDER BY     l.screen_id, l.object_group_id
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql, rec_ext.object_alias, '$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = ''
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF;
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
       

        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %, attached_id = %, html_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id, rec.attached_screen_id , rec.html_screen_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;

          IF v_test_templ = 0 THEN
                 IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN
                     v_sql:=  v_sql || ';  ';
                    ELSE
                     v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
                END IF ;
          ELSE
                IF v_test_templ = 1 THEN
                    IF v_sql ILIKE '%CREATE TEMPORARY TABLE%' THEN RAISE NOTICE 'cant be analyzed';
                        ELSE
                        v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                    END IF ;
                END IF;
          END IF;

          IF v_using = '' THEN
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN
                EXECUTE v_sql;
                -- trace regime
                
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                     
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                     
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::TEXT || ' , attached_screen_id = ' || rec.attached_screen_id::text || ' , html_screen_id = ' ||  rec.html_screen_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
              
                EXIT;
               EXCEPTION
                WHEN SQLSTATE '40P01' THEN
                  PERFORM pg_sleep(5);
                  -- trace regime
                
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
              
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;
          RAISE NOTICE '%',v_sql;


      IF v_test_templ = 0 THEN  -- условие записи реального результата
            LOOP -- начало - цикл записи результата --
               BEGIN
                DROP TABLE IF EXISTS temp_meta_run_signal;
                CREATE TEMPORARY TABLE temp_meta_run_signal AS
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text'
                           THEN NULL
                           ELSE t.v_value
                      END::float8 AS record_error
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit
                    ---lgi--------------------------------------------------
                    , (t.record_identifier::jsonb ->> 'table_html')::TEXT AS json_table
                    -----------------------------------------------------------
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text'
                           THEN t.v_value
                           ELSE  NULL
                      END::text AS val_value
                FROM temp_out_tbl t
                )
                SELECT
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier
                    , ttt.record_error
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql
                    , ttt.metric
                    , ttt.key_metric
                    , ttt.val_value AS value
                    ---lgi------------
                    , ttt.json_table
                    --------------
                FROM ttt
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_run_signal;
               RAISE NOTICE 'temp_meta_run_signal - %', v_cnt::TEXT;

               -- Добавление текста письма
               DROP TABLE IF EXISTS temp_meta_email_template;
               -- Использование функции в запросе
               CREATE TEMPORARY TABLE temp_meta_email_template AS
               WITH template_data AS (
                     SELECT
                          f.batch_id,
                          f.load_dttm,
                          f.wf_load_id,
                          f.src_cd,
                          f.wf_id,
                          f.schema_src_id,
                          f.table_src_id,
                          f.screen_id,
                          m.email_template_title,
                          m.email_template_body,
                          m."type",
                          f.record_identifier,
                          l.email_recipient_id,
                          l.attached_screen_id ,
                          l.html_screen_id ,
                          --------lgi-----------
                          f.json_table
                          -------------------
               FROM
                      temp_meta_run_signal f
               JOIN s_grnplm_as_cib_gm_dg.meta_signal_link l
                 ON f.screen_id = l.signal_id
               JOIN s_grnplm_as_cib_gm_dg.meta_email_template_ref_table m
                 ON l.email_template_id = m.email_template_id
                AND m.email_template_id = f.record_error::int8
               )
               SELECT
                p.batch_id,
                p.load_dttm,
                p.wf_load_id,
                p.src_cd,
                p.wf_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
           --    p.email_template_body as original_template,
                ----------------------lgi----------------------------
                s_grnplm_as_cib_gm_dg.meta_apply_all_replacements(p.email_template_body, p.record_identifier::jsonb, p.json_table::jsonb) as processed_template,
                -------------------------------------------------------------------------------------------
                p.TYPE,
                r.email_recipient_cd ,
                p.attached_screen_id ,
                p.html_screen_id ,
                a1.attached_json_text AS proccesed_attached ,
                a2.html_json_text AS proccesed_html
                FROM template_data p
                JOIN s_grnplm_as_cib_gm_dg.meta_email_recipient_ref_table r ON p.email_recipient_id = r.email_recipient_id
                LEFT JOIN temp_meta_attached a1 ON a1.attached_screen_id = p.attached_screen_id
                LEFT JOIN temp_meta_attached a2 ON a2.html_screen_id = p.html_screen_id
                DISTRIBUTED BY (schema_src_id, table_src_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_email_template;
               RAISE NOTICE 'temp_meta_email_template - %', v_cnt::TEXT;

                --   v_result := 1;
                INSERT INTO dg_full.meta_run_signal -- meta_error_event_fact
                (
                    batch_id,              -- ID Пакета
                    schema_src_id,         -- ID системы-источника\схемы
                    table_src_id,          -- ID объекта с источника
                    screen_id,             -- Шаблон
                    email_template_title,  -- Заголовок
                    processed_template,    -- Добавление в Тело письма
                    proccesed_attached,    -- Добавление приложение к письму
                    type,                  -- Тип
                    email_recipient_cd,    -- Получатели
                    load_dttm,             -- Дата и время загрузки
                    wf_load_id,            -- Идентификатор загрузки
                    wf_id                  -- Идентификатор потока
                )
                SELECT
                p.batch_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
                p.processed_template,
                p.proccesed_attached,    -- Добавление приложение к письму
                p.TYPE,
                p.email_recipient_cd,
                p.load_dttm,
                p.wf_load_id,
                p.wf_id
                FROM temp_meta_email_template  p
                ;
                -- trace regime
               

                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION
                WHEN SQLSTATE '40P01' THEN
                  PERFORM pg_sleep(5);
                  -- trace regime
                
                  RAISE NOTICE '40P01: INSERT INTO s_grnplm_as_cib_gm_dg.meta_run_signal';
                WHEN OTHERS THEN
                    -- trace regime
                  
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата --
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------

--    ANALYZE s_grnplm_as_cib_gm_dg.meta_run_signal;
--    RAISE NOTICE 'ANALYZE s_grnplm_as_cib_gm_dg.meta_run_signal';
    RAISE NOTICE 'End loop';

    LOOP
            BEGIN
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_signal'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO s_grnplm_as_cib_gm_dg.meta_run_signal';
                -- trace regime
               
                EXIT;
            EXCEPTION
                WHEN SQLSTATE '40P01' THEN
                  PERFORM pg_sleep(5);
                  -- trace regime
                
                  RAISE NOTICE '40P01: INSERT INTO s_grnplm_as_cib_gm_dg.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;


    -- trace regime
  
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_signal'
            , p_wf_load_id
            , p_wf_id
            , 0::int4
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;
    DROP TABLE IF EXISTS temp_meta_run_signal;
    DROP TABLE IF EXISTS temp_meta_email_template;
    DROP TABLE IF EXISTS temp_meta_attached;

    RETURN v_batch_id;


    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
        
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
         
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_signal'
                , p_wf_load_id
                , p_wf_id
                , 3::int4
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;






















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_run_signal_v01(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
    
    
/* Описание параметров и их заполнения
 * Периодический запуск: в сервисе рассылки
 * Проверяем наличие сигналов для рассылки
 * Формируем текст письма
 * p_wf_id      - ид загрузчика
 * p_wf_load_id - ид потока загрузки
 * p_tbl_rstri_wf_load_id - для отдельного потока не фильтруем (-1 - вся таблица, -2 - макс. wf_load_id), проверяем глобально по всему объему данных таблицы
 * */   
      
DECLARE
    v_params         TEXT default '';
    v_res_statements TEXT default '';
    v_batch_id       BIGINT;
    v_sch_src_id     TEXT := ''; 
    v_tbl_src_id     TEXT := ''; 
    v_sql            TEXT := '';
    v_using          TEXT := '';
    v_nm             INT4;
    v_interval_fr     timestamp;
    --v_result         float8;
    rec              record;
    rec_ext          record;
    rec_m            record;
    v_sql_m          TEXT := '';
    v_start_dt       timestamp;
    v_cnt            int8;
    v_test_templ     int8;
    p_tbl_rstri_wf_load_id int8 := -1;
BEGIN
    /* Добавить логгирование  */
    v_params := FORMAT
    (
        'p_wf_load_id = %I, p_tbl_rstri_wf_load_id = %I '
        , p_wf_load_id
        , COALESCE(p_tbl_rstri_wf_load_id,-1)
    );
    -- При задании значения < -1, проводим провеку коректности  скриптов
    IF p_wf_id < -1::int8 THEN 
         v_test_templ := 1; -- 
    ELSE v_test_templ := 0;
    END IF;

       
    IF v_test_templ = 0 THEN 
    v_batch_id := nextval('dg_full.synth_key_seq');
    ELSE 
        IF v_test_templ = 1 THEN
          v_batch_id := -999;
        END IF;
    END IF;
    
    v_start_dt := CURRENT_TIMESTAMP; 
    
    BEGIN 
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_object_ref_table';
    SELECT clock_timestamp() INTO v_interval_fr;
    -- Ветка SQL с алиасами - выполняется с заменой алиасов
    CREATE TEMPORARY TABLE temp_meta_object_ref_table
    ON COMMIT DROP
    AS
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.object_group_id
                , o.attribute_type
            FROM dg_full.vmeta_object_ref_table AS o
            JOIN dg_full.meta_signal_link sl ON o.object_group_id = sl.object_group_id 
            WHERE 1=1
            ORDER BY o.object_group_id
                   , o.object_order
    DISTRIBUTED REPLICATED;       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_object_ref_table;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_object_ref_table - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ('temp_meta_object_ref_table ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_object_ref_table '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -3;
    END;

   BEGIN 
   v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */'|| chr(10) || 'temp_meta_screen_link';
   SELECT clock_timestamp() INTO v_interval_fr;
   CREATE TEMPORARY TABLE temp_meta_screen_link
   ON COMMIT DROP
   AS
    WITH tmp_st1 AS (
        SELECT
              l.object_group_id
            , l.signal_id AS  screen_id
            , og.object_group_type
            , st.screen_sql
            , l.src_cd
            , og.is_active AS og_is_active
            , l.is_active
            , st.is_direct_sql
            , l.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , CASE WHEN st.screen_category LIKE 'Business check%' THEN og.object_group_name ELSE st.screen_category END AS screen_category
            , l.screen_template_id
            , o.schema_src_id 
            , o.table_src_id 
        FROM dg_full.meta_signal_link AS l
        JOIN dg_full.vmeta_object_group_ref_table og 
          ON l.object_group_id  = og.object_group_id
        JOIN (SELECT DISTINCT 
                    o1.object_group_id, o1.schema_src_id, o1.table_src_id 
              FROM dg_full.vmeta_object_ref_table o1
              WHERE 1=1
             ) o
          ON o.object_group_id  = og.object_group_id
        JOIN dg_full.meta_screen_template_ref_table AS st 
          ON l.screen_template_id  = st.screen_template_id 
        WHERE 1=1
            AND l.is_active = 1
            AND og.is_active = 1
            AND og.object_group_type  IN (1,2) -- 1 - Для атрибута всей таблицы, 2 - для всей таблицы
        )
        SELECT DISTINCT
              s1.object_group_id
            , s1.screen_id
            , s1.object_group_type
            , s1.screen_sql
            , s1.src_cd
            , s1.og_is_active
            , s1.is_active
            , s1.is_direct_sql
            , s1.processing_order -- 0 - свод (STG\ODS) - 1 - свод+деталька (DM)
            , s1.screen_category
            , s1.screen_template_id
       FROM tmp_st1 s1
    DISTRIBUTED BY (screen_id);       
    GET DIAGNOSTICS v_cnt = row_count;
    ANALYZE temp_meta_screen_link;
    v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
    RAISE NOTICE 'temp_meta_screen_link - %, %', v_cnt::TEXT, age(clock_timestamp() , v_interval_fr)::TEXT;
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link ' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::text, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);

    EXCEPTION
    
    WHEN OTHERS THEN
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'temp_meta_screen_link '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
    RETURN -2;
    END;

    FOR rec IN 
    (
        SELECT
              l.object_group_id
            , l.screen_id
            , l.object_group_type
            , l.screen_sql
            , l.src_cd
            , l.screen_category
            , l.screen_template_id
            , l.processing_order
        FROM temp_meta_screen_link l 
        ORDER BY     l.screen_id, l.object_group_id 
    ) LOOP   -- начало - цикл проверок -------------
        -- 1 - Проверяем атрибут всей таблицы - возвращаем количество нарушений
        -- 2 - Проверяем всю таблицу
        v_sql := rec.screen_sql;
        v_using := '';
        v_nm := 1;
        -- !!!! -- DROP TABLE IF EXISTS temp_out_tbl;
        FOR rec_ext IN 
        (
            SELECT
                  o.schema_src_id
                , o.table_src_id
                , o.attribute_src_id
                , o.object_alias
                , o.object_order
                , o.node_type_src_id
                , o.attribute_type
            FROM temp_meta_object_ref_table AS o 
            WHERE 1 = 1
                AND o.object_group_id  = rec.object_group_id -- для "прямых" SQL - таблица    
            ORDER BY o.object_order DESC -- обратная сортировка обеспечивает замены зависимых объектов   
        ) LOOP -- начало - замена алиасов на атрибуты -------------
            IF rec_ext.node_type_src_id = 12 THEN
                -- замена значений !!! Имя параметра должно совпадать с именем переменной для замены 
                --v_sql := REPLACE(v_sql,rec_ext.object_alias,rec_ext.attribute_src_id );
                v_sql := REPLACE(v_sql, rec_ext.object_alias, '$' || v_nm::TEXT);
                v_nm := v_nm + 1;
                v_using := v_using ||  CASE WHEN substring(rec_ext.attribute_src_id,1,1) = '$' THEN  substring(rec_ext.attribute_src_id,2) ELSE ''::TEXT END ;
            ELSE 
                -- замена алиасов !!!
                v_sql := REPLACE(v_sql,rec_ext.object_alias, CASE WHEN rec_ext.attribute_src_id IS NULL OR rec_ext.attribute_src_id = '' 
                                                                  THEN rec_ext.schema_src_id || '.' || rec_ext.table_src_id
                                                                  ELSE rec_ext.attribute_src_id END 
                                );
                -- !! RAISE NOTICE 'v_tbl - %', coalesce(rec_ext.attribute_src_id, rec_ext.schema_src_id || '.' || rec_ext.table_src_id);
            END IF; 
            v_sch_src_id := rec_ext.schema_src_id;
            v_tbl_src_id  := rec_ext.table_src_id;
        END LOOP; -- конец - замена алиасов на атрибуты -------------
        -- trace regime
        INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
        VALUES ( 'loop step: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
    
        IF v_sql IS NOT NULL AND v_sql NOT LIKE '%{{%' THEN 
          RAISE NOTICE 'screen_id = % , object_group_id = % , screen_template_id = %', rec.screen_id, rec.object_group_id, rec.screen_template_id;
          -- !! RAISE NOTICE 'v_sql - %', v_sql;

          SELECT clock_timestamp() INTO v_interval_fr;
          
          IF v_test_templ = 0 THEN 
                   v_sql := 'CREATE TEMPORARY TABLE temp_out_tbl AS ' || v_sql || ' DISTRIBUTED RANDOMLY ';
          ELSE      
                IF v_test_templ = 1 THEN
                   v_sql := 'EXPLAIN ANALYZE ' || v_sql;
                END IF;
          END IF;
      
          IF v_using = '' THEN 
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              --!! RAISE NOTICE ' % ' , v_sql ;
              LOOP  -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ('loop step 1: ' || rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION
                  WHEN SQLSTATE '40P01' THEN
                      PERFORM pg_sleep(5);
                      -- trace regime
                      INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 11: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                      RAISE NOTICE '40P01: EXECUTE v_sql';
                  WHEN OTHERS THEN
                      -- trace regime
                      INSERT INTO dg_full.dev_logs (sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                      VALUES ( 'loop step 12: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          ELSE 
              IF right(v_using,1) = ',' THEN v_using := left(v_using,-1); END IF;
              v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || 'Start: screen_id = '|| rec.screen_id::TEXT ||' , object_group_id = ' ||rec.object_group_id::text || ' , screen_template_id = ' || rec.screen_template_id::text;
              LOOP -- начало -- формирование темповой таблицы
               BEGIN 
                EXECUTE v_sql USING COALESCE(p_tbl_rstri_wf_load_id,-1); -- FORMAT('%s', v_using); -- Большой вопрос по замене
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'loop step 2: '|| rec.screen_id::TEXT , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 21: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: EXECUTE v_sql USING';
                WHEN OTHERS THEN
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'loop step 22: ' || rec.screen_id::TEXT||'::'||SQLSTATE||'::'||SQLERRM, clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'EXECUTE v_sql USING: %', SQLSTATE||'::'||SQLERRM;
                    EXIT;
               END;
              END LOOP; -- конец -- формирование темповой таблицы
          END IF ;

      IF v_test_templ = 0 THEN  -- условие записи реального результата 
            LOOP -- начало - цикл записи результата -- 
               BEGIN 
                DROP TABLE IF EXISTS temp_meta_run_signal;
                CREATE TEMPORARY TABLE temp_meta_run_signal AS 
                WITH ttt AS (
                SELECT
                      v_batch_id AS batch_id
                    , v_sch_src_id AS schema_src_id
                    , v_tbl_src_id AS table_src_id
                    , rec.screen_id AS screen_id
                    , 0::INTEGER AS event_time
                    , t.record_identifier 
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN NULL 
                           ELSE t.v_value 
                      END::float8 AS record_error 
                    , clock_timestamp() AS load_dttm
                    , p_wf_load_id AS wf_load_id
                    , rec.src_cd AS src_cd
                    , p_wf_id AS wf_id
                    , v_sql::TEXT AS check_sql 
                    , rec.screen_category::text AS metric
                    , rec.screen_category::text AS key_metric
                    , (t.record_identifier::jsonb ->> 'unit')::TEXT AS json_unit  
                    , pg_typeof(t.v_value)::TEXT AS val_type
                    , CASE WHEN pg_typeof(t.v_value)::text = 'text' 
                           THEN t.v_value 
                           ELSE  NULL
                      END::text AS val_value 
                FROM temp_out_tbl t
                ) 
                SELECT 
                      ttt.batch_id
                    , ttt.schema_src_id
                    , ttt.table_src_id
                    , ttt.screen_id
                    , ttt.event_time
                    , ttt.record_identifier 
                    , ttt.record_error 
                    , ttt.load_dttm
                    , ttt.wf_load_id
                    , ttt.src_cd
                    , ttt.wf_id
                    , ttt.check_sql 
                    , ttt.metric
                    , ttt.key_metric
                    , ttt.val_value AS value
                FROM ttt
                DISTRIBUTED BY (batch_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_run_signal;

               -- Добавление текста письма
               DROP TABLE IF EXISTS temp_meta_email_template;
               -- Использование функции в запросе
               CREATE TEMPORARY TABLE temp_meta_email_template AS 
               WITH template_data AS (
                     SELECT 
                          f.batch_id,
                          f.load_dttm,
                          f.wf_load_id,
                          f.src_cd,
                          f.wf_id,
                          f.schema_src_id, 
                          f.table_src_id, 
                          f.screen_id, 
                          m.email_template_title, 
                          m.email_template_body, 
                          m."type",
                          f.record_identifier,
                          l.email_recipient_id
               FROM 
                      temp_meta_run_signal f
               JOIN dg_full.meta_signal_link l 
                 ON f.screen_id = l.signal_id 
               JOIN dg_full.meta_email_template_ref_table m 
                 ON l.email_template_id = m.email_template_id 
                AND m.email_template_id = f.record_error::int8 
               )
               SELECT
                p.batch_id,
                p.load_dttm,
                p.wf_load_id,
                p.src_cd,
                p.wf_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
           --    p.email_template_body as original_template,
                dg_full.meta_apply_all_replacements(p.email_template_body, p.record_identifier::jsonb) as processed_template,
                p.TYPE,
                r.email_recipient_cd 
                FROM template_data p
                JOIN dg_full.meta_email_recipient_ref_table r ON p.email_recipient_id = r.email_recipient_id  
                DISTRIBUTED BY (schema_src_id, table_src_id);
               GET DIAGNOSTICS v_cnt = row_count;
               ANALYZE temp_meta_email_template;
               
                --   v_result := 1;
                INSERT INTO dg_full.meta_run_signal -- meta_error_event_fact
                (
                    batch_id,              -- ID Пакета
                    schema_src_id,         -- ID системы-источника\схемы
                    table_src_id,          -- ID объекта с источника
                    screen_id,             -- Шаблон
                    email_template_title,  -- Заголовок
                    processed_template, -- Тело письма
                    type,               -- Тип
                    email_recipient_cd, -- Получатели
                    load_dttm,          -- Дата и время загрузки
                    wf_load_id,         -- Идентификатор загрузки
                    wf_id               -- Идентификатор потока
                )
                SELECT 
                p.batch_id,
                p.schema_src_id,
                p.table_src_id,
                p.screen_id,
                p.email_template_title,
                p.processed_template,
                p.TYPE,
                p.email_recipient_cd, 
                p.load_dttm,
                p.wf_load_id,
                p.wf_id
                FROM temp_meta_email_template  p
                ;
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_run_signal' , clock_timestamp(), v_params || ', v_cnt ' || v_cnt::TEXT,  'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            
                DROP TABLE IF EXISTS temp_out_tbl;
                RAISE NOTICE 'End: % ', age(clock_timestamp() , v_interval_fr)::TEXT;
                EXIT;
               EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_run_signal 1: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_run_signal';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_run_signal 2: '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                    RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;               
                    EXIT;
               END;
            END LOOP; -- конец - цикл записи результата -- 
          END IF;   -- условие записи реального результата ---
        ELSE
          RAISE NOTICE 'Start else: screen_id = % , object_group_id = % , screen_template_id = % , Нарушение замены алиасов.', rec.screen_id, rec.object_group_id, rec.screen_template_id;
        END IF;
        -- 0 - проверяем каждый атрибут каждой строки
        ---------------- !! ------------------
    END LOOP; -- конец - цикл проверок -------------
    
--    ANALYZE dg_full.meta_run_signal;
--    RAISE NOTICE 'ANALYZE dg_full.meta_run_signal';
    RAISE NOTICE 'End loop';
   IF v_test_templ = 0 THEN -- запись реального результата --
    LOOP
            BEGIN 
                INSERT INTO dg_full.meta_batch_fact
                (
                batch_id
                , start_dt
                , end_dt
                , stts
                , batch_params
                , load_dttm
                , wf_load_id
                , src_cd
                )
                VALUES 
                (
                v_batch_id
                , v_start_dt
                , CLOCK_TIMESTAMP()
                , 'return_meta_run_signal'
                , v_params
                , CURRENT_TIMESTAMP
                , p_wf_load_id
                , 'GP'
                );
                RAISE NOTICE 'INSERT INTO dg_full.meta_run_signal';
                -- trace regime
                INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                VALUES ( 'meta_batch_fact' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                EXIT;
            EXCEPTION  
                WHEN SQLSTATE '40P01' THEN 
                  PERFORM pg_sleep(5);
                  -- trace regime
                  INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                  VALUES ( 'meta_batch_fact 1 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                  RAISE NOTICE '40P01: INSERT INTO dg_full.meta_batch_fact';
                WHEN OTHERS THEN
                    -- trace regime
                    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
                    VALUES ( 'meta_batch_fact 2 '||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
                    /* В цикле записей может быть много
                     *  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
                    (
                        v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                        , v_params
                        , 'return_meta_run_signal'
                        , p_wf_load_id
                        , p_wf_id
                        , 3::int4 
                    );*/
                RAISE NOTICE 'End: %', SQLSTATE||'::'||SQLERRM;
                EXIT;
            END;
    END LOOP;
  END IF; -- запись реального результата --
    -- trace regime
    INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
    VALUES ( 'End' , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
/*    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
        (
            v_res_statements
            , v_params
            , 'return_meta_run_signal'
            , p_wf_load_id
            , p_wf_id
            , 0::int4 
    )    ;*/
    DROP TABLE IF EXISTS temp_meta_object_ref_table;
    DROP TABLE IF EXISTS temp_meta_screen_link;

    RETURN v_batch_id;
    
    
    EXCEPTION
        WHEN SQLSTATE '40P01' THEN
            PERFORM pg_sleep(5);
            -- trace regime
            INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
            VALUES ( 'End 1'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            RAISE NOTICE '40P01: Global';
        WHEN OTHERS THEN
             -- trace regime
             INSERT INTO dg_full.dev_logs ( sql_query, run_tm, param, proc_name, wf_load_id, wf_id, level)
             VALUES ( 'End 2'||'::'||SQLSTATE||'::'||SQLERRM , clock_timestamp(), v_params, 'return_meta_run_signal', p_wf_load_id, p_wf_id, 3::int4);
            /*  PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs
            (
                v_res_statements||'::'||SQLSTATE||'::'||SQLERRM
                , v_params
                , 'return_meta_run_signal'
                , p_wf_load_id
                , p_wf_id
                , 3::int4 
            ); */
            RAISE EXCEPTION '(%:%:%:%)', v_params, v_res_statements, SQLSTATE, SQLERRM
            ;
END
;





$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_scheduler_hsat(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
    
    


/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-06-06 Fix wrong scheduler for objects  @restore@
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_scheduler_hsat';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_scheduler_hsat';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);


-- из факта пробуем собрать cron расписание
-- можно ставить для всех событий 
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_fact_to_cron - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE  temp_fact_to_cron AS 
WITH temp_fact0 AS (
         SELECT 
            f0.sch_name,
            f0.tbl_name,
            f0.max_dttm AS max_dttm,
            CASE WHEN extract(dow FROM f0.max_dttm) = 0 THEN 7
                 ELSE extract(dow FROM f0.max_dttm) 
            END AS week_day     -- запуск в день недели
           FROM dg_full.vmeta_execute_fact f0 
        )
        , temp_fact_an AS (
         SELECT 
            f0.sch_name,
            f0.tbl_name,
            percentile_disc(0.85::double precision) WITHIN GROUP (ORDER BY f0.week_day) AS percentile_disc_85,
            count(*) AS fact_cn  -- кол-во выборки для статистики
           FROM temp_fact0 f0
           GROUP BY f0.sch_name,
                    f0.tbl_name
        )
        , temp_fact AS (
        SELECT
            f.sch_name AS schema_src_id,
            f.tbl_name AS node_src_id,
            a.percentile_disc_85,
            a.fact_cn, 
            ' * * ' || string_agg(DISTINCT f.week_day::int4::text, ','::text) AS cron_ -- метка расписания по фактам запусков
        FROM temp_fact0 f
        LEFT JOIN temp_fact_an a ON f.sch_name = a.sch_name AND f.tbl_name = a.tbl_name
        WHERE f.week_day <= coalesce(a.percentile_disc_85 , f.week_day)
        GROUP BY 
        f.sch_name,
        f.tbl_name,
        a.percentile_disc_85,
        a.fact_cn
        )
        , min15 AS (
         SELECT 
              ts_report.ts_report::timestamp without time zone AS gregor_dt
           FROM generate_series(date_trunc('year'::text, now()- '1 year'::interval)::timestamp without time zone::timestamp with time zone, now() + '7 days'::interval, '00:30:00'::interval) ts_report(ts_report)
        )
        , started AS (
         SELECT 
            tt.tbl_name AS relname,
            tt.sch_name AS nspname,
--            tt.max_dttm AS fact_started, -- fact
            st.gregor_dt::time AS backet_started,
            sum(CASE WHEN tt.max_eff_from_dttm::date >= date_trunc('month',now()) - '1 month'::interval THEN 2 
                     WHEN tt.max_eff_from_dttm::date < date_trunc('month',now())- '1 month'::interval THEN 1
                     ELSE NULL END ) AS backet_started_cnt
            -- !! count(st.gregor_dt::time) AS backet_started_cnt
           FROM dg_full.vmeta_execute_fact tt -- dg_full.vmeta_execute_fact tt
             LEFT JOIN min15 st ON tt.max_eff_from_dttm >= st.gregor_dt AND tt.max_eff_from_dttm <= (st.gregor_dt + '00:30:00'::interval)
          WHERE 1 = 1 
            AND tt.max_eff_from_dttm IS NOT NULL
          GROUP BY tt.tbl_name, tt.sch_name, st.gregor_dt::time  -- , tt.max_dttm
        )
        , ended AS (
         SELECT 
            tt.tbl_name AS relname,
            tt.sch_name AS nspname,
--            tt.max_dttm AS fact_ended, -- fact
            en.gregor_dt::time AS backet_ended,
            sum(CASE WHEN tt.max_eff_to_dttm::date >= date_trunc('month',now()) - '1 month'::interval THEN 2 
                     WHEN tt.max_eff_to_dttm::date < date_trunc('month',now())- '1 month'::interval THEN 1
                     ELSE NULL END ) AS backet_ended_cnt
            --count(en.gregor_dt::time) AS backet_ended_cnt
           FROM dg_full.vmeta_execute_fact tt -- dg_full.vmeta_execute_fact tt
             LEFT JOIN min15 en ON tt.max_eff_to_dttm >= en.gregor_dt AND tt.max_eff_to_dttm <= (en.gregor_dt + '00:30:00'::interval)
          WHERE 1 = 1 
            AND tt.max_eff_from_dttm IS NOT NULL
          GROUP BY tt.tbl_name, tt.sch_name, en.gregor_dt::time --, tt.max_dttm
        )
        , temp_se AS (
         SELECT 
            COALESCE(s.nspname, e.nspname) AS schema_src_id,
            COALESCE(s.relname, e.relname) AS node_src_id,
--            COALESCE(s.fact_started, e.fact_ended) AS fact,
            COALESCE(s.backet_started, e.backet_ended)::time without time zone AS backet,
            COALESCE(s.backet_started_cnt, 0::bigint) AS backet_started_cnt,
            row_number() OVER (PARTITION BY COALESCE(s.nspname, e.nspname), COALESCE(s.relname, e.relname) ORDER BY COALESCE(s.backet_started_cnt, 0::bigint) DESC, COALESCE(s.backet_started, e.backet_ended)) AS rn_started,
            COALESCE(e.backet_ended_cnt, 0::bigint) AS backet_ended_cnt,
            row_number() OVER (PARTITION BY COALESCE(s.nspname, e.nspname), COALESCE(s.relname, e.relname) ORDER BY COALESCE(e.backet_ended_cnt, 0::bigint) DESC,
                CASE
                    WHEN s.backet_started < e.backet_ended THEN 1
                    ELSE 0
                END DESC, COALESCE(s.backet_started, e.backet_ended)) AS rn_ended
           FROM started s
             FULL JOIN ended e ON s.relname = e.relname AND s.nspname = e.nspname AND s.backet_started = e.backet_ended
          WHERE 1 = 1
          )
          SELECT 
            se.schema_src_id,
            se.node_src_id,
            se.backet,
            f1.fact_cn,
            EXTRACT(MINUTE FROM se.backet)::TEXT || ' ' || EXTRACT(HOUR FROM se.backet)::text || 
            CASE WHEN f1.cron_ LIKE ' * * 1,2,3,4,' THEN  ' * * 1-4'::TEXT
                 WHEN f1.cron_ LIKE ' * * 1,2,3,4,5,' THEN  ' * * 1-5'::TEXT
                 WHEN f1.cron_ LIKE ' * * 1,2,3,4,5,6,' THEN  ' * * 1-6'::TEXT
                 WHEN f1.cron_ LIKE ' * * 1,2,3,4,5,6,7,' THEN  ' * * 1-7'::TEXT
                 ELSE f1.cron_
            END AS fact_cron 
          FROM temp_se se
          LEFT JOIN temp_fact f1 ON se.schema_src_id = f1.schema_src_id AND se.node_src_id = f1.node_src_id 
          WHERE 1=1
          AND se.rn_started  = 1 -- макс кол-во начала запусков в это время
          AND se.backet IS NOT NULL 
          --AND se.rn_ended = 1
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_fact_to_cron;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_fact_to_cron - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

-- dg_full.vmeta_sg_category source

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_espd0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE  temp_espd0 AS 
SELECT 
  w.category_id 
, cc.name_ AS category_nm
, w.profile_id 
, w.id AS wf_id 
, w.name_ AS wf_nm
, w.scheduled 
, w.single_loading 
, max(CASE WHEN cp.param = 'folderName' THEN cp.prior_value ELSE NULL END::TEXT) AS folder_nm
, max(CASE WHEN cp.param = 'workflowName' THEN cp.prior_value ELSE NULL END::TEXT) AS workflow_nm
FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
JOIN dg_full.vmeta_sg_category cc 
  ON w.category_id = cc.id 
JOIN dg_full.vctl_param cp 
  ON w.id = cp.wf_id 
WHERE 1=1
AND w.deleted  = FALSE 
AND w.profile_id IN (150)
AND w.id <> 81257
GROUP BY 1,2,3,4,5,6,7
HAVING ( max(CASE WHEN cp.param = 'folderName' THEN cp.prior_value ELSE NULL END::TEXT) || 
         max(CASE WHEN cp.param = 'workflowName' THEN cp.prior_value ELSE NULL END::TEXT) ) IS NOT NULL  
DISTRIBUTED BY (wf_nm, category_nm)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_espd0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_espd0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
         
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_espd - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_espd AS 
SELECT 
  e1.category_id 
, e1.category_nm
, e1.profile_id 
, e1.wf_id 
, e1.wf_nm
, e1.folder_nm
, e1.workflow_nm
, e1.scheduled 
, e1.single_loading 
, mel.edge_id, mel.src_schema_src_id, mel.src_node_src_id, mel.target_schema_src_id , mel.target_node_src_id , mel.edge_type_src_id , mel.is_active 
FROM temp_espd0 e1
LEFT JOIN s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link mel ON e1.wf_nm::text = mel.src_node_src_id::TEXT -- замена на АС СПОД (Ввод данных)
WHERE 1=1
AND e1.wf_nm LIKE 'ESPD%'
AND mel.src_node_src_id::text ~~ 'ESPD%'::TEXT
AND mel.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link h1)
DISTRIBUTED BY (target_schema_src_id , target_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_espd;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_espd - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_wf0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_wf0 AS 
SELECT 
  w.category_id 
, cc.name_ AS category_nm
, w.profile_id 
, w.id AS wf_id 
, w.name_ AS wf_nm
, cp.param, cp.prior_value
, CASE WHEN cp.param IN ('tgt_entity_id','entity_id') THEN cp.prior_value ELSE NULL END::text AS tgt_entity_id
, CASE WHEN cp.param IN ('stg_schema_name','stg_schema') OR cp.param LIKE 'hive_schema_name%' THEN cp.prior_value 
       WHEN cp.param IN ('function_schema') THEN cp.prior_value
  ELSE NULL END::text 
  AS src_schema_name
, CASE WHEN cp.param IN ('stg_table_name','object_name')  OR cp.param LIKE 'hive_table_name%' THEN cp.prior_value 
       WHEN cp.param IN ('function_name') THEN cp.prior_value
  ELSE NULL END::text 
  AS src_table_name
, CASE WHEN w.name_ NOT LIKE '%_restore' AND cp.param IN ('ods_schema_name','ods_schema','mart_schema_name', 'tgt_schema_name') THEN cp.prior_value 
       WHEN w.name_ LIKE '%_restore' AND cp.param IN ('mart_schema_name_backup') THEN cp.prior_value
  ELSE NULL END::text 
  AS tgt_schema_name
, CASE WHEN w.name_ NOT LIKE '%_restore' AND cp.param IN ('ods_table_name','object_name','mart_table_name','tgt_table_name') THEN cp.prior_value 
       WHEN w.name_ LIKE '%_restore' AND cp.param IN ('mart_table_name_backup') THEN cp.prior_value
  ELSE NULL END::text 
  AS tgt_table_name
, CASE -- !!WHEN cp.param::text IN ('function_name') THEN 'Function'
       WHEN cp.param::text IN ('ods_table_name'::TEXT,'object_name'::TEXT,'mart_table_name'::TEXT, 'tgt_table_name'::TEXT) THEN 'Table'
       ELSE NULL::character varying
  END::text AS tgt_node_type_cd
, CASE WHEN cp.param = 'enable_dq' THEN cp.prior_value ELSE NULL END::text AS enable_dq
, CASE WHEN cp.param = 'column_key_list' THEN cp.prior_value ELSE NULL END::text AS column_key_list
, w.scheduled 
, w.single_loading 
FROM dg_full.vctl_wf w
JOIN dg_full.vmeta_sg_category cc 
  ON w.category_id = cc.id 
JOIN dg_full.vctl_param cp 
  ON w.id = cp.wf_id 
WHERE 1=1
AND w.deleted  = FALSE 
--AND w.profile_id IN ( 329, 334/*,150 espd, 74 gp_cib*/) -- потоки екс остались на 74 - gp_cib
AND w.id IN (
SELECT DISTINCT cp1.wf_id 
FROM dg_full.vctl_param cp1
WHERE 1=1
AND lower(cp1.param) LIKE '%connectionlake%'
AND cp1.prior_value LIKE '%TIB%')
AND w.id <> 81257 -- workaround - не выключенный кривой поток
DISTRIBUTED BY (wf_nm , category_nm)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_wf0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_wf0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_wf AS 
SELECT 
  w1.category_id 
, w1.category_nm
, w1.profile_id 
, w1.wf_id 
, w1.wf_nm
, w1.scheduled 
, w1.single_loading 
, max(w1.tgt_entity_id) AS tgt_entity_id
, max(w1.src_schema_name) AS src_schema_name
, max(w1.src_table_name) AS src_table_name
, max(w1.tgt_schema_name) AS tgt_schema_name
, max(w1.tgt_table_name) AS tgt_table_name
, max(w1.enable_dq) AS enable_dq
, max(w1.column_key_list) AS column_key_list
FROM temp_wf0 w1
GROUP BY 1,2,3,4,5,6,7
HAVING ( max(w1.tgt_entity_id)   || -- !! max(w1.src_schema_name) || max(w1.src_table_name) ||
         max(w1.tgt_schema_name) || max(w1.tgt_table_name)  /*|| max(w1.enable_dq)*/ ) IS NOT NULL  
DISTRIBUTED BY (tgt_entity_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_wf;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_wf - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_final0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_final0 AS 
SELECT 
--, es.category_id  AS es_category_id
--, es.profile_id AS es_profile_id  
--, es.wf_id AS es_wf_id
  es.category_nm          AS espd_src_schema_src_id
, es.wf_nm                AS espd_src_node_src_id
, es.target_schema_src_id AS espd_target_schema_src_id
, es.target_node_src_id   AS espd_target_node_src_id
, es.scheduled            AS espd_scheduled
, es.single_loading       AS espd_single_loading
, cwes1."active"          AS espd_ev_active  -- стоит на триггерах
, cwes1.stat_id           AS espd_stat_id
, cwes1.stat_type         AS espd_stat_type
, cwts1."active"          AS espd_tm_active -- стоит на расписании
, CASE WHEN cwts1."active" IS FALSE THEN NULL 
       ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cwts1.sched,'mon','1'),'tue','2'),'wed','3'),'thu','4'),'fri','5') , 'sat','6'),'sun', '7')
  END AS espd_sched
, te.src_schema_name      AS wf_src_schema_src_id
, te.src_table_name       AS wf_src_node_src_id
--, te.category_id 
--, te.profile_id 
--, te.wf_id 
, te.category_nm     AS wf_target_schema_src_id
, te.wf_nm           AS wf_target_node_src_id
, te.category_nm     AS wf1_src_schema_src_id
, te.wf_nm           AS wf1_src_node_src_id
, DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path") AS wf1_target_schema_src_id
, e.name_            AS wf1_target_node_src_id
, DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path") AS wf2_src_schema_src_id
, e.name_            AS wf2_src_node_src_id
, te.tgt_schema_name AS wf2_target_schema_src_id
, te.tgt_table_name  AS wf2_target_node_src_id
, te.enable_dq
, te.column_key_list
--, te.tgt_entity_id
, te.scheduled      AS wf_scheduled
, te.single_loading AS wf_single_loading
, cwes2."active" AS wf_ev_active -- стоит на триггерах
, cwes2.stat_id AS wf_stat_id
, cwes2.stat_type AS wf_stat_type
, cwts2."active" AS wf_tm_active -- стоит на расписании
, CASE WHEN cwts2."active" IS FALSE THEN NULL 
       ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cwts2.sched,'mon','1'),'tue','2'),'wed','3'),'thu','4'),'fri','5')  , 'sat','6'),'sun', '7')
  END AS wf_sched
FROM temp_wf te
LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity e ON te.tgt_entity_id = e.id::text
LEFT JOIN temp_espd es ON es.target_schema_src_id = te.src_schema_name AND es.target_node_src_id = te.src_table_name
LEFT JOIN dg_full.vctl_wf_event_sched cwes1 ON es.wf_id = cwes1.wf_id::int4 
LEFT JOIN dg_full.vctl_wf_time_sched cwts1  ON es.wf_id = cwts1.wf_id 
LEFT JOIN dg_full.vctl_wf_event_sched cwes2 ON te.wf_id = cwes2.wf_id::int4  -- стоит на триггерах 
LEFT JOIN dg_full.vctl_wf_time_sched cwts2  ON te.wf_id = cwts2.wf_id  -- стоит на расписании
WHERE 1=1
DISTRIBUTED BY (wf_target_schema_src_id, wf_target_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_final0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_final0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_final - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_final AS 
SELECT DISTINCT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'GP'::TEXT AS src_cd,
-1::numeric(22) AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
f.espd_target_node_src_id::name AS node_src_id,
f.espd_target_schema_src_id AS schema_src_id,
'Auto'::TEXT AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
1::int4 AS node_type_src_id,
f.espd_sched AS period_type_comment,
CASE WHEN f.espd_ev_active = 'true' THEN '{''wf_event_sched'': [''' || COALESCE(f.espd_src_node_src_id,'~') || ''']}'
     WHEN f.espd_single_loading  = 'true' THEN 'Разовая загрузка'::text 
     WHEN f.espd_tm_active IS TRUE THEN 'На расписании'::text
     ELSE '~ 1'::TEXT 
END AS period_refresh_comment,
'Из ctl реплики'::text AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
f.espd_scheduled AS  is_wf_time_sched_active
FROM temp_final0 f
WHERE 1=1
AND (f.espd_target_node_src_id|| f.espd_target_schema_src_id) IS NOT NULL
UNION 
SELECT DISTINCT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'CTL'::TEXT AS src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
f.wf_target_node_src_id::name AS node_src_id,
f.wf_target_schema_src_id AS schema_src_id,
'Auto'::TEXT AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
1::int4 AS node_type_src_id,
f.wf_sched AS period_type_comment,
CASE WHEN f.wf_ev_active = 'true' THEN '{''wf_event_sched'': [''' || COALESCE(f.espd_src_node_src_id,'~') || ''']}'
     WHEN f.wf_single_loading  = 'true' THEN 'Разовая загрузка'::text 
     WHEN f.wf_tm_active IS TRUE THEN 'На расписании'::text
     ELSE '~ 2'::TEXT 
END AS period_refresh_comment,
'Из ctl реплики'::text AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
f.wf_scheduled AS  is_wf_time_sched_active
FROM temp_final0 f
WHERE 1=1
AND (f.wf_target_schema_src_id || f.wf_target_node_src_id ) IS NOT NULL
UNION 
SELECT DISTINCT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'GP'::TEXT AS src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
f.wf2_target_node_src_id::name AS node_src_id,
f.wf2_target_schema_src_id AS schema_src_id,
'Auto'::TEXT AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
1::int4 AS node_type_src_id,
COALESCE(f.wf_sched, f.espd_sched) AS period_type_comment,
CASE WHEN f.wf_ev_active = 'true' THEN '{''wf_event_sched'': [''' || COALESCE(f.espd_src_node_src_id,'~') || ''']}'
     WHEN f.wf_single_loading  = 'true' THEN 'Разовая загрузка'::text 
     WHEN f.wf_tm_active IS TRUE THEN 'На расписании'::text
     ELSE '~ 3'::TEXT 
END AS period_refresh_comment,
'Из ctl реплики'::text AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
f.wf_scheduled AS  is_wf_time_sched_active
FROM temp_final0 f
WHERE 1=1
AND (f.wf2_target_node_src_id|| f.wf2_target_schema_src_id) IS NOT NULL
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_final;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_final - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_final2 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_final2 AS 
SELECT 
f.scheduler_id,
f.load_dttm,
f.src_cd,
f.wf_load_id,
f.eff_from_dttm,
f.eff_to_dttm,
f.last_seen_dttm,
f.node_src_id,
f.schema_src_id,
f.scheduler_type_src_id,
f.dt_from,
f.dt_to,
f.time_from,
f.time_to,
f.period_type_id,
f.every_times,
f.source_object,
f.run_function_src_id,
f.node_type_src_id,
f.period_type_comment,
f.period_refresh_comment,
f.user_refresh,
f.ods_ready,
f.dm_ready,
f.ods_ready_dt,
f.dm_ready_dt,
f.ods_ready_tm,
f.dm_ready_tm,
f.ods_start,
f.ods_start_tm,
f.is_wf_time_sched_active,
'Auto'::TEXT AS flg_
FROM temp_final f
UNION 
SELECT  -- из ручного справочника с фиксированным кроном
h.scheduler_id::bpchar(10),
current_timestamp AS load_dttm,
h.src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
h.node_src_id,
h.schema_src_id,
h.scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
h.period_type_id,
h.every_times,
h.source_object,
h.run_function_src_id,
h.node_type_src_id,
REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(h.period_type_comment,'mon','1'),'tue','2'),'wed','3'),'thu','4'),'fri','5') , 'sat','6'),'sun', '7') AS period_type_comment,
h.period_refresh_comment,
h.user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
h.is_wf_time_sched_active,
'Manual'::TEXT AS flg_
-- !! FROM dg_full.meta_scheduler_hsat h
FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_scheduler_hsat h -- замена на АС СПОД (Ввод данных)
WHERE 1=1
AND h.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_scheduler_hsat h1)
AND NOT EXISTS (SELECT * FROM temp_final p WHERE p.schema_src_id = h.schema_src_id AND p.node_src_id = h.node_src_id)
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_final2;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_final2 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_scheduler_hsat - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_scheduler_hsat AS 
SELECT 
f2.scheduler_id,
f2.load_dttm,
f2.src_cd,
f2.wf_load_id,
f2.eff_from_dttm,
f2.eff_to_dttm,
f2.last_seen_dttm,
f2.node_src_id,
f2.schema_src_id,
f2.scheduler_type_src_id,
f2.dt_from,
f2.dt_to,
f2.time_from,
f2.time_to,
f2.period_type_id,
f2.every_times,
f2.source_object,
f2.run_function_src_id,
f2.node_type_src_id,
f2.period_type_comment,
f2.period_refresh_comment,
f2.user_refresh,
f2.ods_ready,
f2.dm_ready,
f2.ods_ready_dt,
f2.dm_ready_dt,
f2.ods_ready_tm,
f2.dm_ready_tm,
f2.ods_start,
f2.ods_start_tm,
f2.is_wf_time_sched_active,
f2.flg_
FROM temp_final2 f2 
UNION
SELECT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'GP'::TEXT AS src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
pgc.relname::TEXT AS node_src_id,
pgn.nspname AS schema_src_id,
'Auto' AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
        CASE pgc.relkind
            WHEN 'r'::"char" THEN 1::int4
            WHEN 'p'::"char" THEN 1::int4
            WHEN 'v'::"char" THEN 2::int4
            WHEN 'm'::"char" THEN 2::int4
            ELSE NULL::int4
        END AS node_type_src_id,
NULL::TEXT AS period_type_comment,
'{''wf_event_sched'': [] }'::TEXT AS period_refresh_comment,
'Из pg_class' AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
TRUE::bool AS  is_wf_time_sched_active,
'Auto'::TEXT AS flg_
FROM pg_class pgc 
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
  WHERE 1 = 1 
  AND pgn.nspname IN ('s_grnplm_as_cib_gm_mart_tib','s_grnplm_as_cib_gm_mart_tib_lpm','s_grnplm_as_cib_gm_mart_digital_ref')
  AND pgc.relname !~~ '%_prt_%'::text 
  AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
  AND NOT EXISTS (SELECT * FROM temp_final2 p WHERE p.schema_src_id = pgn.nspname AND p.node_src_id = pgc.relname::text)
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_scheduler_hsat;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_scheduler_hsat - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
   

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_ctl_stts_from_jr - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_ctl_stts_from_jr AS 
SELECT 
  j.id 
, j.description , j.summary 
, j.created 
, j.resolutiondate AS resolutiondate
, p.pkey||'-' || j.issuenum AS issuenum
, CASE WHEN (j.summary ilike '[ПКАП ГР]%Остановка потока на ПРОМ' OR  j.summary ilike  '[ПКАП ГР]%Снять поток с автозапуска ПРОМ') THEN 'Останов'
       WHEN (j.summary ilike '[ПКАП ГР]%Запуск поток% на ПРОМ%') THEN 'Запуск'
       WHEN (it.pname='Incident Task'  AND j.summary ILIKE 'IM%') THEN 'В раб-е'
       ELSE '.'
 END AS run_status      
, iss.pname
FROM s_grnplm_as_cib_ods_internal_jira_sigma.project p
JOIN s_grnplm_as_cib_ods_internal_jira_sigma.jiraissue j ON p.id = j.project 
JOIN s_grnplm_as_cib_ods_internal_jira_sigma.issuestatus iss ON j.issuestatus = iss.id 
JOIN s_grnplm_as_cib_ods_internal_jira_sigma.issuetype it ON it.id=j.issuetype
WHERE --p.pkey IN ('DOTIB','TIBDS')
--AND (j.summary ilike '[ПКАП ГР]%Остановка потока на ПРОМ'
-- OR  j.summary ilike  '[ПКАП ГР]%Снять поток с автозапуска ПРОМ'
-- OR j.summary iLIKE '[ПКАП ГР][TIBDS] Запуск поток% на ПРОМ%' )
(p.pkey IN ('TIBDS') AND it.pname='Incident Task'  AND j.summary ILIKE 'IM%' AND iss.pname  IN ('Open','Backlog','In Progress','To Do','Need Info'))
OR 
 (p.pkey = ('DOTIB') 
AND iss.pname NOT IN ('Cancelled','Open','Backlog','In Progress','To Do','Need Info')
AND j.summary ILIKE '[ПКАП ГР]%ПРОМ%'
AND j.summary NOT LIKE '[ПКАП ГР] Запрос информации с ПРОМа')
DISTRIBUTED BY (id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_ctl_stts_from_jr;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_ctl_stts_from_jr - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf0 AS 
SELECT 
  n.schema_src_id , n.node_src_id , n.node_cd , n.is_active , n.node_type_src_id , n.node_type_cd 
, s.id 
FROM dg_full.meta_node_ref_table n
LEFT JOIN temp_ctl_stts_from_jr s ON /*s.description ILIKE '%'::text || n.schema_src_id || '%'::TEXT AND*/ s.description ILIKE '%'::text || n.node_src_id || '%'::TEXT
WHERE 1=1
-- AND n.src_cd = 'CTL'
-- AND node_type_src_id = 5
DISTRIBUTED BY (schema_src_id , node_src_id, node_type_cd)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf1 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf1 AS 
SELECT 
  wf0.schema_src_id , wf0.node_src_id , wf0.node_cd , wf0.is_active , wf0.node_type_src_id , wf0.node_type_cd 
, max(wf0.id ) AS last_id
FROM temp_jr_wf0 wf0
GROUP BY wf0.schema_src_id , wf0.node_src_id , wf0.node_cd , wf0.is_active, wf0.node_type_src_id , wf0.node_type_cd
DISTRIBUTED BY (schema_src_id , node_src_id, node_type_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf1;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf1 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf2 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf2 AS 
SELECT 
wf1.schema_src_id,
wf1.node_src_id,
wf1.node_type_src_id,
wf1.node_type_cd,
wf1.is_active,
wf1.last_id
FROM temp_jr_wf1 wf1
JOIN temp_ctl_stts_from_jr s ON  wf1.last_id = s.id
UNION ALL 
SELECT 
COALESCE(e.target_schema_src_id , wf1.schema_src_id) AS schema_src_id,
COALESCE(e.target_node_src_id , wf1.node_src_id) AS node_src_id,
n.node_type_src_id AS node_type_src_id ,
COALESCE(e.tgt_node_type_cd , wf1.node_type_cd) AS node_type_cd,
COALESCE(e.is_active , wf1.is_active) AS is_active,
wf1.last_id
FROM temp_jr_wf1 wf1
JOIN dg_full.meta_edge_link e ON wf1.schema_src_id = e.src_schema_src_id 
JOIN dg_full.meta_node_ref_table n ON e.target_schema_src_id = n.schema_src_id AND e.target_node_src_id = n.node_src_id 
AND wf1.node_src_id = e.src_node_src_id 
AND wf1.node_type_cd = e.src_node_type_cd
WHERE 1=1
AND e.tgt_node_type_cd = 'Table'
DISTRIBUTED BY (last_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf2;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf2 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf3 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf3 AS 
SELECT DISTINCT 
wf2.schema_src_id,
wf2.node_src_id,
wf2.node_type_src_id,
wf2.node_type_cd,
wf2.is_active,
s.id,
s.description,
s.summary,
s.created,
s.resolutiondate,
s.issuenum,
s.run_status,
s.pname
FROM temp_jr_wf2 wf2
JOIN temp_ctl_stts_from_jr s ON  wf2.last_id = s.id
DISTRIBUTED BY (schema_src_id,node_src_id,node_type_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf3;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf3 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
----------------------------------------------------------------------------


   
/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_scheduler_hsat';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_scheduler_hsat;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_scheduler_hsat'|| chr(9) || v_deleted_row::text;


/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_scheduler_hsat ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_scheduler_hsat 
(
scheduler_id,
load_dttm,
src_cd,
wf_load_id,
eff_from_dttm,
eff_to_dttm,
last_seen_dttm,
node_src_id,
schema_src_id,
scheduler_type_src_id,
dt_from,
dt_to,
time_from,
time_to,
period_type_id,
every_times,
source_object,
run_function_src_id,
node_type_src_id,
period_type_comment,
period_refresh_comment,
user_refresh,
ods_ready,
dm_ready,
ods_ready_dt,
dm_ready_dt,
ods_ready_tm,
dm_ready_tm,
ods_start,
ods_start_tm,
is_wf_time_sched_active
)
SELECT  
t.scheduler_id,
t.load_dttm,
t.src_cd,
t.wf_load_id,
t.eff_from_dttm,
t.eff_to_dttm,
t.last_seen_dttm,
t.node_src_id,
t.schema_src_id,
t.scheduler_type_src_id,
t.dt_from,
t.dt_to,
t.time_from,
t.time_to,
t.period_type_id,
fc.fact_cn AS every_times, -- кол-во фактов, на которых собираем статистику
t.source_object,
t.run_function_src_id,
t.node_type_src_id,
REPLACE(REPLACE(REPLACE(CASE WHEN t.flg_ = 'Auto' AND t.period_refresh_comment LIKE '%wf_event_sched%' THEN COALESCE(fc.fact_cron, t.period_type_comment)
                             WHEN t.flg_ = 'Manual' THEN t.period_type_comment
                             ELSE COALESCE(t.period_type_comment, fc.fact_cron)
                             END,'1,2,3,4,5,6','1-6'),'1,2,3,4,5','1-5'),'1,2,3,4','1-4') AS period_type_comment,
COALESCE(w.run_status  || '|' || w.issuenum || '|' || w.resolutiondate::text , t.period_refresh_comment) AS period_refresh_comment,
--COALESCE(w.issuenum || '|' || w.resolutiondate::text , t.period_refresh_comment) AS period_refresh_comment,
t.user_refresh,
REPLACE(REPLACE(REPLACE(fc.fact_cron,'1,2,3,4,5,6','1-6'),'1,2,3,4,5','1-5'),'1,2,3,4','1-4') AS ods_ready, -- cron формируем из факта -- 
t.dm_ready,
t.ods_ready_dt,
t.dm_ready_dt,
t.ods_ready_tm,
t.dm_ready_tm,
t.ods_start,
t.ods_start_tm,
t.is_wf_time_sched_active
FROM temp_meta_scheduler_hsat t
LEFT JOIN temp_jr_wf3 w ON t.schema_src_id = w.schema_src_id AND t.node_src_id = w.node_src_id  AND t.node_type_src_id = w.node_type_src_id -- !!!!
LEFT JOIN temp_fact_to_cron fc ON t.schema_src_id = fc.schema_src_id AND t.node_src_id = fc.node_src_id;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_scheduler_hsat' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_scheduler_hsat - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_scheduler_hsat;
DROP TABLE IF EXISTS temp_espd0;
DROP TABLE IF EXISTS temp_espd;
DROP TABLE IF EXISTS temp_wf0;
DROP TABLE IF EXISTS temp_wf;
DROP TABLE IF EXISTS temp_final;
DROP TABLE IF EXISTS temp_final0;
DROP TABLE IF EXISTS temp_final2;
DROP TABLE IF EXISTS temp_fact_to_cron;
DROP TABLE IF EXISTS temp_ctl_stts_from_jr;
DROP TABLE IF EXISTS temp_jr_wf0;
DROP TABLE IF EXISTS temp_jr_wf1;
DROP TABLE IF EXISTS temp_jr_wf2;
DROP TABLE IF EXISTS temp_jr_wf3;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;






$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_scheduler_hsat_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	


/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-06-06 Fix wrong scheduler for objects  @restore@
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_scheduler_hsat';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_scheduler_hsat';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);


-- из факта пробуем собрать cron расписание
-- можно ставить для всех событий 
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_fact_to_cron - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE  temp_fact_to_cron AS 
WITH temp_fact0 AS (
         SELECT 
            f0.sch_name,
            f0.tbl_name,
            f0.max_dttm AS max_dttm,
            CASE WHEN extract(dow FROM f0.max_dttm) = 0 THEN 7
                 ELSE extract(dow FROM f0.max_dttm) 
            END AS week_day     -- запуск в день недели
           FROM dg_full.vmeta_execute_fact f0 
        )
        , temp_fact_an AS (
         SELECT 
            f0.sch_name,
            f0.tbl_name,
            percentile_disc(0.85::double precision) WITHIN GROUP (ORDER BY f0.week_day) AS percentile_disc_85,
            count(*) AS fact_cn  -- кол-во выборки для статистики
           FROM temp_fact0 f0
           GROUP BY f0.sch_name,
                    f0.tbl_name
        )
        , temp_fact AS (
        SELECT
            f.sch_name AS schema_src_id,
            f.tbl_name AS node_src_id,
            a.percentile_disc_85,
            a.fact_cn, 
            ' * * ' || string_agg(DISTINCT f.week_day::int4::text, ','::text) AS cron_ -- метка расписания по фактам запусков
        FROM temp_fact0 f
        LEFT JOIN temp_fact_an a ON f.sch_name = a.sch_name AND f.tbl_name = a.tbl_name
        WHERE f.week_day <= coalesce(a.percentile_disc_85 , f.week_day)
        GROUP BY 
        f.sch_name,
        f.tbl_name,
        a.percentile_disc_85,
        a.fact_cn
        )
        , min15 AS (
         SELECT 
              ts_report.ts_report::timestamp without time zone AS gregor_dt
           FROM generate_series(date_trunc('year'::text, now()- '1 year'::interval)::timestamp without time zone::timestamp with time zone, now() + '7 days'::interval, '00:30:00'::interval) ts_report(ts_report)
        )
        , started AS (
         SELECT 
            tt.tbl_name AS relname,
            tt.sch_name AS nspname,
--            tt.max_dttm AS fact_started, -- fact
            st.gregor_dt::time AS backet_started,
            sum(CASE WHEN tt.max_eff_from_dttm::date >= date_trunc('month',now()) - '1 month'::interval THEN 2 
                     WHEN tt.max_eff_from_dttm::date < date_trunc('month',now())- '1 month'::interval THEN 1
                     ELSE NULL END ) AS backet_started_cnt
            -- !! count(st.gregor_dt::time) AS backet_started_cnt
           FROM dg_full.vmeta_execute_fact tt -- dg_full.vmeta_execute_fact tt
             LEFT JOIN min15 st ON tt.max_eff_from_dttm >= st.gregor_dt AND tt.max_eff_from_dttm <= (st.gregor_dt + '00:30:00'::interval)
          WHERE 1 = 1 
            AND tt.max_eff_from_dttm IS NOT NULL
          GROUP BY tt.tbl_name, tt.sch_name, st.gregor_dt::time  -- , tt.max_dttm
        )
        , ended AS (
         SELECT 
            tt.tbl_name AS relname,
            tt.sch_name AS nspname,
--            tt.max_dttm AS fact_ended, -- fact
            en.gregor_dt::time AS backet_ended,
            sum(CASE WHEN tt.max_eff_to_dttm::date >= date_trunc('month',now()) - '1 month'::interval THEN 2 
                     WHEN tt.max_eff_to_dttm::date < date_trunc('month',now())- '1 month'::interval THEN 1
                     ELSE NULL END ) AS backet_ended_cnt
            --count(en.gregor_dt::time) AS backet_ended_cnt
           FROM dg_full.vmeta_execute_fact tt -- dg_full.vmeta_execute_fact tt
             LEFT JOIN min15 en ON tt.max_eff_to_dttm >= en.gregor_dt AND tt.max_eff_to_dttm <= (en.gregor_dt + '00:30:00'::interval)
          WHERE 1 = 1 
            AND tt.max_eff_from_dttm IS NOT NULL
          GROUP BY tt.tbl_name, tt.sch_name, en.gregor_dt::time --, tt.max_dttm
        )
        , temp_se AS (
         SELECT 
            COALESCE(s.nspname, e.nspname) AS schema_src_id,
            COALESCE(s.relname, e.relname) AS node_src_id,
--            COALESCE(s.fact_started, e.fact_ended) AS fact,
            COALESCE(s.backet_started, e.backet_ended)::time without time zone AS backet,
            COALESCE(s.backet_started_cnt, 0::bigint) AS backet_started_cnt,
            row_number() OVER (PARTITION BY COALESCE(s.nspname, e.nspname), COALESCE(s.relname, e.relname) ORDER BY COALESCE(s.backet_started_cnt, 0::bigint) DESC, COALESCE(s.backet_started, e.backet_ended)) AS rn_started,
            COALESCE(e.backet_ended_cnt, 0::bigint) AS backet_ended_cnt,
            row_number() OVER (PARTITION BY COALESCE(s.nspname, e.nspname), COALESCE(s.relname, e.relname) ORDER BY COALESCE(e.backet_ended_cnt, 0::bigint) DESC,
                CASE
                    WHEN s.backet_started < e.backet_ended THEN 1
                    ELSE 0
                END DESC, COALESCE(s.backet_started, e.backet_ended)) AS rn_ended
           FROM started s
             FULL JOIN ended e ON s.relname = e.relname AND s.nspname = e.nspname AND s.backet_started = e.backet_ended
          WHERE 1 = 1
          )
          SELECT 
            se.schema_src_id,
            se.node_src_id,
            se.backet,
            f1.fact_cn,
            EXTRACT(MINUTE FROM se.backet)::TEXT || ' ' || EXTRACT(HOUR FROM se.backet)::text || 
            CASE WHEN f1.cron_ LIKE ' * * 1,2,3,4,' THEN  ' * * 1-4'::TEXT
                 WHEN f1.cron_ LIKE ' * * 1,2,3,4,5,' THEN  ' * * 1-5'::TEXT
                 WHEN f1.cron_ LIKE ' * * 1,2,3,4,5,6,' THEN  ' * * 1-6'::TEXT
                 WHEN f1.cron_ LIKE ' * * 1,2,3,4,5,6,7,' THEN  ' * * 1-7'::TEXT
                 ELSE f1.cron_
            END AS fact_cron 
          FROM temp_se se
          LEFT JOIN temp_fact f1 ON se.schema_src_id = f1.schema_src_id AND se.node_src_id = f1.node_src_id 
          WHERE 1=1
          AND se.rn_started  = 1 -- макс кол-во начала запусков в это время
          AND se.backet IS NOT NULL 
          --AND se.rn_ended = 1
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_fact_to_cron;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_fact_to_cron - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

-- dg_full.vmeta_sg_category source

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_espd0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE  temp_espd0 AS 
SELECT 
  w.category_id 
, cc.name_ AS category_nm
, w.profile_id 
, w.id AS wf_id 
, w.name_ AS wf_nm
, w.scheduled 
, w.single_loading 
, max(CASE WHEN cp.param = 'folderName' THEN cp.prior_value ELSE NULL END::TEXT) AS folder_nm
, max(CASE WHEN cp.param = 'workflowName' THEN cp.prior_value ELSE NULL END::TEXT) AS workflow_nm
FROM dg_full.vctl_wf w -- s_grnplm_as_cib_gm_stg_espd.ctl_wf w
JOIN dg_full.vmeta_sg_category cc 
  ON w.category_id = cc.id 
JOIN dg_full.vctl_param cp 
  ON w.id = cp.wf_id 
WHERE 1=1
AND w.deleted  = FALSE 
AND w.profile_id IN (150)
AND w.id <> 81257
GROUP BY 1,2,3,4,5,6,7
HAVING ( max(CASE WHEN cp.param = 'folderName' THEN cp.prior_value ELSE NULL END::TEXT) || 
         max(CASE WHEN cp.param = 'workflowName' THEN cp.prior_value ELSE NULL END::TEXT) ) IS NOT NULL  
DISTRIBUTED BY (wf_nm, category_nm)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_espd0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_espd0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
         
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_espd - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_espd AS 
SELECT 
  e1.category_id 
, e1.category_nm
, e1.profile_id 
, e1.wf_id 
, e1.wf_nm
, e1.folder_nm
, e1.workflow_nm
, e1.scheduled 
, e1.single_loading 
, mel.edge_id, mel.src_schema_src_id, mel.src_node_src_id, mel.target_schema_src_id , mel.target_node_src_id , mel.edge_type_src_id , mel.is_active 
FROM temp_espd0 e1
LEFT JOIN s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link mel ON e1.wf_nm::text = mel.src_node_src_id::TEXT -- замена на АС СПОД (Ввод данных)
WHERE 1=1
AND e1.wf_nm LIKE 'ESPD%'
AND mel.src_node_src_id::text ~~ 'ESPD%'::TEXT
AND mel.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_edge_link h1)
DISTRIBUTED BY (target_schema_src_id , target_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_espd;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_espd - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_wf0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_wf0 AS 
SELECT 
  w.category_id 
, cc.name_ AS category_nm
, w.profile_id 
, w.id AS wf_id 
, w.name_ AS wf_nm
, cp.param, cp.prior_value
, CASE WHEN cp.param IN ('tgt_entity_id','entity_id') THEN cp.prior_value ELSE NULL END::text AS tgt_entity_id
, CASE WHEN cp.param IN ('stg_schema_name','stg_schema') OR cp.param LIKE 'hive_schema_name%' THEN cp.prior_value 
       WHEN cp.param IN ('function_schema') THEN cp.prior_value
  ELSE NULL END::text 
  AS src_schema_name
, CASE WHEN cp.param IN ('stg_table_name','object_name')  OR cp.param LIKE 'hive_table_name%' THEN cp.prior_value 
       WHEN cp.param IN ('function_name') THEN cp.prior_value
  ELSE NULL END::text 
  AS src_table_name
, CASE WHEN w.name_ NOT LIKE '%_restore' AND cp.param IN ('ods_schema_name','ods_schema','mart_schema_name', 'tgt_schema_name') THEN cp.prior_value 
       WHEN w.name_ LIKE '%_restore' AND cp.param IN ('mart_schema_name_backup') THEN cp.prior_value
  ELSE NULL END::text 
  AS tgt_schema_name
, CASE WHEN w.name_ NOT LIKE '%_restore' AND cp.param IN ('ods_table_name','object_name','mart_table_name','tgt_table_name') THEN cp.prior_value 
       WHEN w.name_ LIKE '%_restore' AND cp.param IN ('mart_table_name_backup') THEN cp.prior_value
  ELSE NULL END::text 
  AS tgt_table_name
, CASE -- !!WHEN cp.param::text IN ('function_name') THEN 'Function'
       WHEN cp.param::text IN ('ods_table_name'::TEXT,'object_name'::TEXT,'mart_table_name'::TEXT, 'tgt_table_name'::TEXT) THEN 'Table'
       ELSE NULL::character varying
  END::text AS tgt_node_type_cd
, CASE WHEN cp.param = 'enable_dq' THEN cp.prior_value ELSE NULL END::text AS enable_dq
, CASE WHEN cp.param = 'column_key_list' THEN cp.prior_value ELSE NULL END::text AS column_key_list
, w.scheduled 
, w.single_loading 
FROM dg_full.vctl_wf w
JOIN dg_full.vmeta_sg_category cc 
  ON w.category_id = cc.id 
JOIN dg_full.vctl_param cp 
  ON w.id = cp.wf_id 
WHERE 1=1
AND w.deleted  = FALSE 
--AND w.profile_id IN ( 329, 334/*,150 espd, 74 gp_cib*/) -- потоки екс остались на 74 - gp_cib
AND w.id IN (
SELECT DISTINCT cp1.wf_id 
FROM dg_full.vctl_param cp1
WHERE 1=1
AND lower(cp1.param) LIKE '%connectionlake%'
AND cp1.prior_value LIKE '%TIB%')
AND w.id <> 81257 -- workaround - не выключенный кривой поток
DISTRIBUTED BY (wf_nm , category_nm)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_wf0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_wf0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_wf AS 
SELECT 
  w1.category_id 
, w1.category_nm
, w1.profile_id 
, w1.wf_id 
, w1.wf_nm
, w1.scheduled 
, w1.single_loading 
, max(w1.tgt_entity_id) AS tgt_entity_id
, max(w1.src_schema_name) AS src_schema_name
, max(w1.src_table_name) AS src_table_name
, max(w1.tgt_schema_name) AS tgt_schema_name
, max(w1.tgt_table_name) AS tgt_table_name
, max(w1.enable_dq) AS enable_dq
, max(w1.column_key_list) AS column_key_list
FROM temp_wf0 w1
GROUP BY 1,2,3,4,5,6,7
HAVING ( max(w1.tgt_entity_id)   || -- !! max(w1.src_schema_name) || max(w1.src_table_name) ||
         max(w1.tgt_schema_name) || max(w1.tgt_table_name)  /*|| max(w1.enable_dq)*/ ) IS NOT NULL  
DISTRIBUTED BY (tgt_entity_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_wf;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_wf - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_final0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_final0 AS 
SELECT 
--, es.category_id  AS es_category_id
--, es.profile_id AS es_profile_id  
--, es.wf_id AS es_wf_id
  es.category_nm          AS espd_src_schema_src_id
, es.wf_nm                AS espd_src_node_src_id
, es.target_schema_src_id AS espd_target_schema_src_id
, es.target_node_src_id   AS espd_target_node_src_id
, es.scheduled            AS espd_scheduled
, es.single_loading       AS espd_single_loading
, cwes1."active"          AS espd_ev_active  -- стоит на триггерах
, cwes1.stat_id           AS espd_stat_id
, cwes1.stat_type         AS espd_stat_type
, cwts1."active"          AS espd_tm_active -- стоит на расписании
, CASE WHEN cwts1."active" IS FALSE THEN NULL 
       ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cwts1.sched,'mon','1'),'tue','2'),'wed','3'),'thu','4'),'fri','5') , 'sat','6'),'sun', '7')
  END AS espd_sched
, te.src_schema_name      AS wf_src_schema_src_id
, te.src_table_name       AS wf_src_node_src_id
--, te.category_id 
--, te.profile_id 
--, te.wf_id 
, te.category_nm     AS wf_target_schema_src_id
, te.wf_nm           AS wf_target_node_src_id
, te.category_nm     AS wf1_src_schema_src_id
, te.wf_nm           AS wf1_src_node_src_id
, DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path") AS wf1_target_schema_src_id
, e.name_            AS wf1_target_node_src_id
, DECODE(e."path",''::text,'xx'::TEXT, NULL::text,'xx'::TEXT, e."path") AS wf2_src_schema_src_id
, e.name_            AS wf2_src_node_src_id
, te.tgt_schema_name AS wf2_target_schema_src_id
, te.tgt_table_name  AS wf2_target_node_src_id
, te.enable_dq
, te.column_key_list
--, te.tgt_entity_id
, te.scheduled      AS wf_scheduled
, te.single_loading AS wf_single_loading
, cwes2."active" AS wf_ev_active -- стоит на триггерах
, cwes2.stat_id AS wf_stat_id
, cwes2.stat_type AS wf_stat_type
, cwts2."active" AS wf_tm_active -- стоит на расписании
, CASE WHEN cwts2."active" IS FALSE THEN NULL 
       ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cwts2.sched,'mon','1'),'tue','2'),'wed','3'),'thu','4'),'fri','5')  , 'sat','6'),'sun', '7')
  END AS wf_sched
FROM temp_wf te
LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_entity e ON te.tgt_entity_id = e.id::text
LEFT JOIN temp_espd es ON es.target_schema_src_id = te.src_schema_name AND es.target_node_src_id = te.src_table_name
LEFT JOIN dg_full.vctl_wf_event_sched cwes1 ON es.wf_id = cwes1.wf_id::int4 
LEFT JOIN dg_full.vctl_wf_time_sched cwts1  ON es.wf_id = cwts1.wf_id 
LEFT JOIN dg_full.vctl_wf_event_sched cwes2 ON te.wf_id = cwes2.wf_id::int4  -- стоит на триггерах 
LEFT JOIN dg_full.vctl_wf_time_sched cwts2  ON te.wf_id = cwts2.wf_id  -- стоит на расписании
WHERE 1=1
DISTRIBUTED BY (wf_target_schema_src_id, wf_target_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_final0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_final0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_final - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_final AS 
SELECT DISTINCT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'GP'::TEXT AS src_cd,
-1::numeric(22) AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
f.espd_target_node_src_id::name AS node_src_id,
f.espd_target_schema_src_id AS schema_src_id,
'Auto'::TEXT AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
1::int4 AS node_type_src_id,
f.espd_sched AS period_type_comment,
CASE WHEN f.espd_ev_active = 'true' THEN '{''wf_event_sched'': [''' || COALESCE(f.espd_src_node_src_id,'~') || ''']}'
     WHEN f.espd_single_loading  = 'true' THEN 'Разовая загрузка'::text 
     WHEN f.espd_tm_active IS TRUE THEN 'На расписании'::text
     ELSE '~ 1'::TEXT 
END AS period_refresh_comment,
'Из ctl реплики'::text AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
f.espd_scheduled AS  is_wf_time_sched_active
FROM temp_final0 f
WHERE 1=1
AND (f.espd_target_node_src_id|| f.espd_target_schema_src_id) IS NOT NULL
UNION 
SELECT DISTINCT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'CTL'::TEXT AS src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
f.wf_target_node_src_id::name AS node_src_id,
f.wf_target_schema_src_id AS schema_src_id,
'Auto'::TEXT AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
1::int4 AS node_type_src_id,
f.wf_sched AS period_type_comment,
CASE WHEN f.wf_ev_active = 'true' THEN '{''wf_event_sched'': [''' || COALESCE(f.espd_src_node_src_id,'~') || ''']}'
     WHEN f.wf_single_loading  = 'true' THEN 'Разовая загрузка'::text 
     WHEN f.wf_tm_active IS TRUE THEN 'На расписании'::text
     ELSE '~ 2'::TEXT 
END AS period_refresh_comment,
'Из ctl реплики'::text AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
f.wf_scheduled AS  is_wf_time_sched_active
FROM temp_final0 f
WHERE 1=1
AND (f.wf_target_schema_src_id || f.wf_target_node_src_id ) IS NOT NULL
UNION 
SELECT DISTINCT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'GP'::TEXT AS src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
f.wf2_target_node_src_id::name AS node_src_id,
f.wf2_target_schema_src_id AS schema_src_id,
'Auto'::TEXT AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
1::int4 AS node_type_src_id,
COALESCE(f.wf_sched, f.espd_sched) AS period_type_comment,
CASE WHEN f.wf_ev_active = 'true' THEN '{''wf_event_sched'': [''' || COALESCE(f.espd_src_node_src_id,'~') || ''']}'
     WHEN f.wf_single_loading  = 'true' THEN 'Разовая загрузка'::text 
     WHEN f.wf_tm_active IS TRUE THEN 'На расписании'::text
     ELSE '~ 3'::TEXT 
END AS period_refresh_comment,
'Из ctl реплики'::text AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
f.wf_scheduled AS  is_wf_time_sched_active
FROM temp_final0 f
WHERE 1=1
AND (f.wf2_target_node_src_id|| f.wf2_target_schema_src_id) IS NOT NULL
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_final;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_final - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_final2 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_final2 AS 
SELECT 
f.scheduler_id,
f.load_dttm,
f.src_cd,
f.wf_load_id,
f.eff_from_dttm,
f.eff_to_dttm,
f.last_seen_dttm,
f.node_src_id,
f.schema_src_id,
f.scheduler_type_src_id,
f.dt_from,
f.dt_to,
f.time_from,
f.time_to,
f.period_type_id,
f.every_times,
f.source_object,
f.run_function_src_id,
f.node_type_src_id,
f.period_type_comment,
f.period_refresh_comment,
f.user_refresh,
f.ods_ready,
f.dm_ready,
f.ods_ready_dt,
f.dm_ready_dt,
f.ods_ready_tm,
f.dm_ready_tm,
f.ods_start,
f.ods_start_tm,
f.is_wf_time_sched_active,
'Auto'::TEXT AS flg_
FROM temp_final f
UNION 
SELECT  -- из ручного справочника с фиксированным кроном
h.scheduler_id::bpchar(10),
current_timestamp AS load_dttm,
h.src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
h.node_src_id,
h.schema_src_id,
h.scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
h.period_type_id,
h.every_times,
h.source_object,
h.run_function_src_id,
h.node_type_src_id,
REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(h.period_type_comment,'mon','1'),'tue','2'),'wed','3'),'thu','4'),'fri','5') , 'sat','6'),'sun', '7') AS period_type_comment,
h.period_refresh_comment,
h.user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
h.is_wf_time_sched_active,
'Manual'::TEXT AS flg_
-- !! FROM dg_full.meta_scheduler_hsat h
FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_scheduler_hsat h -- замена на АС СПОД (Ввод данных)
WHERE 1=1
AND h.dl_file_id::int8 = (SELECT max(h1.dl_file_id::int8)  FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_scheduler_hsat h1)
AND NOT EXISTS (SELECT * FROM temp_final p WHERE p.schema_src_id = h.schema_src_id AND p.node_src_id = h.node_src_id)
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_final2;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_final2 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_scheduler_hsat - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_scheduler_hsat AS 
SELECT 
f2.scheduler_id,
f2.load_dttm,
f2.src_cd,
f2.wf_load_id,
f2.eff_from_dttm,
f2.eff_to_dttm,
f2.last_seen_dttm,
f2.node_src_id,
f2.schema_src_id,
f2.scheduler_type_src_id,
f2.dt_from,
f2.dt_to,
f2.time_from,
f2.time_to,
f2.period_type_id,
f2.every_times,
f2.source_object,
f2.run_function_src_id,
f2.node_type_src_id,
f2.period_type_comment,
f2.period_refresh_comment,
f2.user_refresh,
f2.ods_ready,
f2.dm_ready,
f2.ods_ready_dt,
f2.dm_ready_dt,
f2.ods_ready_tm,
f2.dm_ready_tm,
f2.ods_start,
f2.ods_start_tm,
f2.is_wf_time_sched_active,
f2.flg_
FROM temp_final2 f2 
UNION
SELECT 
'-1'::bpchar(10) AS scheduler_id,
current_timestamp AS load_dttm,
'GP'::TEXT AS src_cd,
-1::int4 AS wf_load_id,
'1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
'2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
now() AS last_seen_dttm,
pgc.relname::TEXT AS node_src_id,
pgn.nspname AS schema_src_id,
'Auto' AS scheduler_type_src_id,
NULL::int4 AS dt_from,
NULL::int4 AS dt_to,
NULL::int4 AS time_from,
NULL::int4 AS time_to,
1::int4 AS period_type_id,
NULL::int4 AS every_times,
NULL::text AS source_object,
NULL::text AS run_function_src_id,
        CASE pgc.relkind
            WHEN 'r'::"char" THEN 1::int4
            WHEN 'p'::"char" THEN 1::int4
            WHEN 'v'::"char" THEN 2::int4
            WHEN 'm'::"char" THEN 2::int4
            ELSE NULL::int4
        END AS node_type_src_id,
NULL::TEXT AS period_type_comment,
'{''wf_event_sched'': [] }'::TEXT AS period_refresh_comment,
'Из pg_class' AS user_refresh,
NULL::text AS ods_ready,
NULL::text AS dm_ready,
NULL::date AS ods_ready_dt,
NULL::date AS dm_ready_dt,
NULL::time AS ods_ready_tm,
NULL::time AS dm_ready_tm,
NULL::text AS ods_start,
NULL::time AS ods_start_tm,
TRUE::bool AS  is_wf_time_sched_active,
'Auto'::TEXT AS flg_
FROM pg_class pgc 
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
  WHERE 1 = 1 
  AND pgn.nspname IN ('s_grnplm_as_cib_gm_mart_tib','s_grnplm_as_cib_gm_mart_tib_lpm','s_grnplm_as_cib_gm_mart_digital_ref')
  AND pgc.relname !~~ '%_prt_%'::text 
  AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
  AND NOT EXISTS (SELECT * FROM temp_final2 p WHERE p.schema_src_id = pgn.nspname AND p.node_src_id = pgc.relname::text)
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_scheduler_hsat;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_scheduler_hsat - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
   

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_ctl_stts_from_jr - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_ctl_stts_from_jr AS 
SELECT 
  j.id 
, j.description , j.summary 
, j.created 
, j.resolutiondate AS resolutiondate
, p.pkey||'-' || j.issuenum AS issuenum
, CASE WHEN (j.summary ilike '[ПКАП ГР]%Остановка потока на ПРОМ' OR  j.summary ilike  '[ПКАП ГР]%Снять поток с автозапуска ПРОМ') THEN 'Останов'
       WHEN (j.summary ilike '[ПКАП ГР]%Запуск поток% на ПРОМ%') THEN 'Запуск'
       WHEN (it.pname='Incident Task'  AND j.summary ILIKE 'IM%') THEN 'В раб'
       ELSE '.'
 END AS run_status      
, iss.pname
FROM s_grnplm_as_cib_ods_internal_jira_sigma.project p
JOIN s_grnplm_as_cib_ods_internal_jira_sigma.jiraissue j ON p.id = j.project 
JOIN s_grnplm_as_cib_ods_internal_jira_sigma.issuestatus iss ON j.issuestatus = iss.id 
JOIN s_grnplm_as_cib_ods_internal_jira_sigma.issuetype it ON it.id=j.issuetype
WHERE --p.pkey IN ('DOTIB','TIBDS')
--AND (j.summary ilike '[ПКАП ГР]%Остановка потока на ПРОМ'
-- OR  j.summary ilike  '[ПКАП ГР]%Снять поток с автозапуска ПРОМ'
-- OR j.summary iLIKE '[ПКАП ГР][TIBDS] Запуск поток% на ПРОМ%' )
(p.pkey IN ('TIBDS') AND it.pname='Incident Task'  AND j.summary ILIKE 'IM%' AND iss.pname  IN ('Open','Backlog','In Progress','To Do','Need Info'))
OR 
 (p.pkey = ('DOTIB') 
AND iss.pname NOT IN ('Cancelled','Open','Backlog','In Progress','To Do','Need Info')
AND j.summary ILIKE '[ПКАП ГР]%ПРОМ%'
AND j.summary NOT LIKE '[ПКАП ГР] Запрос информации с ПРОМа')
DISTRIBUTED BY (id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_ctl_stts_from_jr;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_ctl_stts_from_jr - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf0 AS 
SELECT 
  n.schema_src_id , n.node_src_id , n.node_cd , n.is_active , n.node_type_src_id , n.node_type_cd 
, s.id 
FROM dg_full.meta_node_ref_table n
LEFT JOIN temp_ctl_stts_from_jr s ON /*s.description ILIKE '%'::text || n.schema_src_id || '%'::TEXT AND*/ s.description ILIKE '%'::text || n.node_src_id || ' %'::TEXT
WHERE 1=1
-- AND n.src_cd = 'CTL'
-- AND node_type_src_id = 5
DISTRIBUTED BY (schema_src_id , node_src_id, node_type_cd)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf0;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf0 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf1 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf1 AS 
SELECT 
  wf0.schema_src_id , wf0.node_src_id , wf0.node_cd , wf0.is_active , wf0.node_type_src_id , wf0.node_type_cd 
, max(wf0.id ) AS last_id
FROM temp_jr_wf0 wf0
GROUP BY wf0.schema_src_id , wf0.node_src_id , wf0.node_cd , wf0.is_active, wf0.node_type_src_id , wf0.node_type_cd
DISTRIBUTED BY (schema_src_id , node_src_id, node_type_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf1;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf1 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf2 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf2 AS 
SELECT 
wf1.schema_src_id,
wf1.node_src_id,
wf1.node_type_src_id,
wf1.node_type_cd,
wf1.is_active,
wf1.last_id
FROM temp_jr_wf1 wf1
JOIN temp_ctl_stts_from_jr s ON  wf1.last_id = s.id
UNION ALL 
SELECT 
COALESCE(e.target_schema_src_id , wf1.schema_src_id) AS schema_src_id,
COALESCE(e.target_node_src_id , wf1.node_src_id) AS node_src_id,
n.node_type_src_id AS node_type_src_id ,
COALESCE(e.tgt_node_type_cd , wf1.node_type_cd) AS node_type_cd,
COALESCE(e.is_active , wf1.is_active) AS is_active,
wf1.last_id
FROM temp_jr_wf1 wf1
JOIN dg_full.meta_edge_link e ON wf1.schema_src_id = e.src_schema_src_id 
JOIN dg_full.meta_node_ref_table n ON e.target_schema_src_id = n.schema_src_id AND e.target_node_src_id = n.node_src_id 
AND wf1.node_src_id = e.src_node_src_id 
AND wf1.node_type_cd = e.src_node_type_cd
WHERE 1=1
AND e.tgt_node_type_cd = 'Table'
DISTRIBUTED BY (last_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf2;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf2 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_jr_wf3 - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_jr_wf3 AS 
SELECT DISTINCT 
wf2.schema_src_id,
wf2.node_src_id,
wf2.node_type_src_id,
wf2.node_type_cd,
wf2.is_active,
s.id,
s.description,
s.summary,
s.created,
s.resolutiondate,
s.issuenum,
s.run_status,
s.pname
FROM temp_jr_wf2 wf2
JOIN temp_ctl_stts_from_jr s ON  wf2.last_id = s.id
DISTRIBUTED BY (schema_src_id,node_src_id,node_type_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_jr_wf3;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_jr_wf3 - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;
----------------------------------------------------------------------------


   
/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_scheduler_hsat';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_scheduler_hsat;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_scheduler_hsat'|| chr(9) || v_deleted_row::text;


/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_scheduler_hsat ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_scheduler_hsat 
(
scheduler_id,
load_dttm,
src_cd,
wf_load_id,
eff_from_dttm,
eff_to_dttm,
last_seen_dttm,
node_src_id,
schema_src_id,
scheduler_type_src_id,
dt_from,
dt_to,
time_from,
time_to,
period_type_id,
every_times,
source_object,
run_function_src_id,
node_type_src_id,
period_type_comment,
period_refresh_comment,
user_refresh,
ods_ready,
dm_ready,
ods_ready_dt,
dm_ready_dt,
ods_ready_tm,
dm_ready_tm,
ods_start,
ods_start_tm,
is_wf_time_sched_active
)
SELECT  
t.scheduler_id,
t.load_dttm,
t.src_cd,
t.wf_load_id,
t.eff_from_dttm,
t.eff_to_dttm,
t.last_seen_dttm,
t.node_src_id,
t.schema_src_id,
t.scheduler_type_src_id,
t.dt_from,
t.dt_to,
t.time_from,
t.time_to,
t.period_type_id,
fc.fact_cn AS every_times, -- кол-во фактов, на которых собираем статистику
t.source_object,
t.run_function_src_id,
t.node_type_src_id,
REPLACE(REPLACE(REPLACE(CASE WHEN t.flg_ = 'Auto' AND t.period_refresh_comment LIKE '%wf_event_sched%' THEN COALESCE(fc.fact_cron, t.period_type_comment)
                             WHEN t.flg_ = 'Manual' THEN t.period_type_comment
                             ELSE COALESCE(t.period_type_comment, fc.fact_cron)
                             END,'1,2,3,4,5,6','1-6'),'1,2,3,4,5','1-5'),'1,2,3,4','1-4') AS period_type_comment,
COALESCE(w.run_status  || '|' || w.issuenum || '|' || w.resolutiondate::text , t.period_refresh_comment) AS period_refresh_comment,
--COALESCE(w.issuenum || '|' || w.resolutiondate::text , t.period_refresh_comment) AS period_refresh_comment,
t.user_refresh,
REPLACE(REPLACE(REPLACE(fc.fact_cron,'1,2,3,4,5,6','1-6'),'1,2,3,4,5','1-5'),'1,2,3,4','1-4') AS ods_ready, -- cron формируем из факта -- 
t.dm_ready,
t.ods_ready_dt,
t.dm_ready_dt,
t.ods_ready_tm,
t.dm_ready_tm,
t.ods_start,
t.ods_start_tm,
t.is_wf_time_sched_active
FROM temp_meta_scheduler_hsat t
LEFT JOIN temp_jr_wf3 w ON t.schema_src_id = w.schema_src_id AND t.node_src_id = w.node_src_id  AND t.node_type_src_id = w.node_type_src_id -- !!!!
LEFT JOIN temp_fact_to_cron fc ON t.schema_src_id = fc.schema_src_id AND t.node_src_id = fc.node_src_id;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_scheduler_hsat' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_scheduler_hsat - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_scheduler_hsat;
DROP TABLE IF EXISTS temp_espd0;
DROP TABLE IF EXISTS temp_espd;
DROP TABLE IF EXISTS temp_wf0;
DROP TABLE IF EXISTS temp_wf;
DROP TABLE IF EXISTS temp_final;
DROP TABLE IF EXISTS temp_final0;
DROP TABLE IF EXISTS temp_final2;
DROP TABLE IF EXISTS temp_fact_to_cron;
DROP TABLE IF EXISTS temp_ctl_stts_from_jr;
DROP TABLE IF EXISTS temp_jr_wf0;
DROP TABLE IF EXISTS temp_jr_wf1;
DROP TABLE IF EXISTS temp_jr_wf2;
DROP TABLE IF EXISTS temp_jr_wf3;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;






$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_scheduler_plan(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
    

/*
 * Change Log
 * 2024-10-04 Create function
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_scheduler_plan';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_scheduler_plan';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

-- plan_   - дата+время плана
-- plan_dt - дата плана
-- время плана берем из среднего факта для триггерных событий   

CREATE TEMPORARY TABLE min15 AS 
 SELECT ts_report.ts_report::timestamp without time zone AS gregor_dt
 FROM generate_series(date_trunc('month'::text, now() - '15 days'::interval)::timestamp without time zone::timestamp with time zone, now() + '7 days'::interval, '00:30:00'::interval) ts_report(ts_report)
 DISTRIBUTED BY (gregor_dt);
RAISE NOTICE 'min15'; 
 
CREATE TEMPORARY TABLE pl_ AS 
         SELECT n.schema_src_id,
            n.node_src_id,
            n.node_type_src_id,
            n.is_active,
            n.node_type_cd,
            s.scheduler_id,
            s.scheduler_type_src_id,
            s.period_type_id,
            s.every_times,
            replace(s.period_type_comment,'/1','') AS period_type_comment,
            s.period_refresh_comment,
            s.user_refresh,
            n.src_cd,
            pt.descr::varchar(250) AS pt_descr,
            s.is_wf_time_sched_active  -- стоит на расписании
           FROM dg_full.meta_node_ref_table n
             JOIN dg_full.meta_scheduler_hsat s ON n.schema_src_id = s.schema_src_id::name AND n.node_src_id = s.node_src_id::name
             LEFT JOIN dg_full.meta_period_type_ref_table pt ON s.period_type_id::text = pt.period_type_id::text
          WHERE 1 = 1 
            -- !! AND n.src_cd = 'GP'::text 
            AND n.node_type_cd::text IN  ('Table'::TEXT, 'View'::TEXT, 'Flow'::TEXT) 
            AND (n.schema_src_id <> ALL (ARRAY[/*'s_grnplm_as_cib_gm_dg'::name, 
                                               's_grnplm_as_cib_gm_mart_dg'::name,*/ 
                                               's_grnplm_as_cib_gm_ods_spod_udlprod'::name, 
                                               's_grnplm_as_cib_gm_meta'::name, 
                                               's_grnplm_as_cib_gm_dv'::name])) 
            AND n.schema_src_id !~~ '%_ld_%'::text 
            -- !! AND n.schema_src_id !~~ '%_stg_%'::text
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'pl_';

CREATE TEMPORARY TABLE plan_ AS 
         SELECT 
            n.schema_src_id,
            n.node_src_id,
            n.node_type_src_id,
            n.is_active,
            n.node_type_cd,
            n.scheduler_id,
            n.scheduler_type_src_id,
            n.period_type_id,
            n.every_times,
            n.period_type_comment,
            n.period_refresh_comment,
            n.user_refresh,
            m.gregor_dt,
            n.src_cd,
            n.pt_descr,
            n.is_wf_time_sched_active
           FROM pl_ n
             CROSS JOIN min15 m
          WHERE 1 = 1 
            -- !! AND n.src_cd = 'GP'::text 
            -- !! AND n.node_type_cd::text <> 'Function'::text 
            AND (n.schema_src_id <> ALL (ARRAY[/*'s_grnplm_as_cib_gm_dg'::name, 
                                               's_grnplm_as_cib_gm_mart_dg'::name,*/ 
                                               's_grnplm_as_cib_gm_ods_spod_udlprod'::name, 
                                               's_grnplm_as_cib_gm_meta'::name, 
                                               's_grnplm_as_cib_gm_dv'::name])) 
            AND n.schema_src_id !~~ '%_ld_%'::text 
            -- !! AND n.schema_src_id !~~ '%_stg_%'::text
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'plan_';

CREATE TEMPORARY TABLE plan_0 AS 
         SELECT 
            n.schema_src_id,
            n.node_src_id,
            n.node_type_src_id,
            n.is_active,
            n.node_type_cd,
            n.scheduler_id,
            n.scheduler_type_src_id,
            n.period_type_id,
            n.every_times,
            n.period_type_comment,
            n.period_refresh_comment,
            n.user_refresh,
            dg_full.meta_match(now(), COALESCE(n.period_type_comment, '0 12 * * 1-5'::text)) AS now_period_type_match,
            n.gregor_dt AS plan_,
            dg_full.meta_match(n.gregor_dt::timestamp with time zone, COALESCE(n.period_type_comment, '0 12 * * 1-5'::text)) AS calendar_period_type_match,
            n.src_cd,
            n.pt_descr,
            n.is_wf_time_sched_active
           FROM plan_ n
          WHERE 1 = 1 
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'plan_0';

CREATE TEMPORARY TABLE plan_1 AS 
         SELECT 
            c.schema_src_id::text AS schema_src_id,
            c.node_src_id::text AS node_src_id,
            c.scheduler_id,
            c.scheduler_type_src_id,
            c.node_type_src_id,
            c.period_type_id,
            c.period_type_comment,
            c.period_refresh_comment,
            c.now_period_type_match,
            c.plan_ AS plan_cron, -- план по cron
            c.every_times,
            c.src_cd,
            c.pt_descr,
            c.plan_,
            c.calendar_period_type_match,
            c.is_wf_time_sched_active
           FROM plan_0 c
          WHERE 1 = 1 
            AND c.calendar_period_type_match IS TRUE
            AND c.plan_::date <= ('now'::text::date + '7 days'::interval)
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'plan_1';

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_scheduler_plan - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_scheduler_plan
AS 
 SELECT  
    c1.schema_src_id::text,
    c1.node_src_id::text,
    c1.scheduler_type_src_id::varchar(250),
    c1.node_type_src_id::int4,
    c1.period_type_id,
    c1.period_type_comment::text,
    c1.period_refresh_comment::text,
    now() AS now_,
    c1.now_period_type_match,
    c1.plan_,
    COALESCE(lead(c1.plan_) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '2999-12-31 00:00:00'::timestamp without time zone) - '00:00:01'::interval AS plan_next,
    c1.plan_::timestamp with time zone - now() AS now_plan_diff,
    c1.pt_descr::varchar(250),
    c1.every_times::int4,
    c1.plan_::date AS plan_dt,
    COALESCE(lead(c1.plan_::date) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '2999-12-31'::date) - '1 day'::interval AS plan_dt_next,
    COALESCE(lag(c1.plan_::date) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '1900-01-01'::date) + '1 day'::interval AS plan_dt_prev,
    COALESCE(lag(c1.plan_) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '1900-01-01 00:00:00'::timestamp without time zone) + '00:00:01'::interval AS plan_prev,
    c1.scheduler_id,
    c1.src_cd::TEXT,
    c1.is_wf_time_sched_active
   FROM plan_1 c1
  WHERE 1 = 1
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_scheduler_plan;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_scheduler_plan - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

DROP TABLE IF EXISTS pl_;
DROP TABLE IF EXISTS plan_;
DROP TABLE IF EXISTS plan_0;
DROP TABLE IF EXISTS plan_1;
DROP TABLE IF EXISTS min15;

/*Очистка 2*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_scheduler_plan';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_scheduler_plan;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_scheduler_plan'|| chr(9) || v_deleted_row::text;


/*Добавление новых данных 2*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_scheduler_plan ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_scheduler_plan 
(
    schema_src_id ,
    node_src_id ,
    scheduler_type_src_id ,
    node_type_src_id ,
    period_type_id ,
    period_type_comment ,
    period_refresh_comment ,
    now_ ,
    now_period_type_match ,
    plan_ ,
    plan_next ,
    now_plan_diff ,
    pt_descr ,
    every_times ,
    plan_dt ,
    plan_dt_next ,
    plan_dt_prev ,
    plan_prev ,
    scheduler_id ,
    is_wf_time_sched_active,
    src_cd ,
    load_dttm ,
    wf_load_id ,
    eff_from_dttm ,
    eff_to_dttm ,
    last_seen_dttm 
    )
SELECT  
    t.schema_src_id,
    t.node_src_id,
    t.scheduler_type_src_id,
    t.node_type_src_id,
    t.period_type_id,
    t.period_type_comment,
    t.period_refresh_comment,
    t.now_,
    t.now_period_type_match,
    t.plan_,
    t.plan_next,
    t.now_plan_diff,
    t.pt_descr,
    t.every_times,
    t.plan_dt,
    t.plan_dt_next,
    t.plan_dt_prev,
    t.plan_prev,
    t.scheduler_id,
    t.is_wf_time_sched_active,
    t.src_cd,
    current_timestamp AS load_dttm,
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm
FROM temp_meta_scheduler_plan t;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_scheduler_plan' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_scheduler_plan - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_scheduler_plan;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_scheduler_plan_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
	
	
    

/*
 * Change Log
 * 2024-10-04 Create function
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_scheduler_plan';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_scheduler_plan';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

-- plan_   - дата+время плана
-- plan_dt - дата плана
-- время плана берем из среднего факта для триггерных событий   

CREATE TEMPORARY TABLE min15 AS 
 SELECT ts_report.ts_report::timestamp without time zone AS gregor_dt
 FROM generate_series(date_trunc('month'::text, now() - '15 days'::interval)::timestamp without time zone::timestamp with time zone, now() + '7 days'::interval, '00:30:00'::interval) ts_report(ts_report)
 DISTRIBUTED BY (gregor_dt);
RAISE NOTICE 'min15'; 
 
CREATE TEMPORARY TABLE pl_ AS 
         SELECT n.schema_src_id,
            n.node_src_id,
            n.node_type_src_id,
            n.is_active,
            n.node_type_cd,
            s.scheduler_id,
            s.scheduler_type_src_id,
            s.period_type_id,
            s.every_times,
            replace(s.period_type_comment,'/1','') AS period_type_comment,
            s.period_refresh_comment,
            s.user_refresh,
            n.src_cd,
            pt.descr::varchar(250) AS pt_descr,
            s.is_wf_time_sched_active  -- стоит на расписании
           FROM dg_full.meta_node_ref_table n
             JOIN dg_full.meta_scheduler_hsat s ON n.schema_src_id = s.schema_src_id::name AND n.node_src_id = s.node_src_id::name
             LEFT JOIN dg_full.meta_period_type_ref_table pt ON s.period_type_id::text = pt.period_type_id::text
          WHERE 1 = 1 
            -- !! AND n.src_cd = 'GP'::text 
            AND n.node_type_cd::text IN  ('Table'::TEXT, 'View'::TEXT, 'Flow'::TEXT) 
            AND (n.schema_src_id <> ALL (ARRAY[/*'s_grnplm_as_cib_gm_dg'::name, 
                                               's_grnplm_as_cib_gm_mart_dg'::name,*/ 
                                               's_grnplm_as_cib_gm_ods_spod_udlprod'::name, 
                                               's_grnplm_as_cib_gm_meta'::name, 
                                               's_grnplm_as_cib_gm_dv'::name])) 
            AND n.schema_src_id !~~ '%_ld_%'::text 
            -- !! AND n.schema_src_id !~~ '%_stg_%'::text
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'pl_';

CREATE TEMPORARY TABLE plan_ AS 
         SELECT 
            n.schema_src_id,
            n.node_src_id,
            n.node_type_src_id,
            n.is_active,
            n.node_type_cd,
            n.scheduler_id,
            n.scheduler_type_src_id,
            n.period_type_id,
            n.every_times,
            n.period_type_comment,
            n.period_refresh_comment,
            n.user_refresh,
            m.gregor_dt,
            n.src_cd,
            n.pt_descr,
            n.is_wf_time_sched_active
           FROM pl_ n
             CROSS JOIN min15 m
          WHERE 1 = 1 
            -- !! AND n.src_cd = 'GP'::text 
            -- !! AND n.node_type_cd::text <> 'Function'::text 
            AND (n.schema_src_id <> ALL (ARRAY[/*'s_grnplm_as_cib_gm_dg'::name, 
                                               's_grnplm_as_cib_gm_mart_dg'::name,*/ 
                                               's_grnplm_as_cib_gm_ods_spod_udlprod'::name, 
                                               's_grnplm_as_cib_gm_meta'::name, 
                                               's_grnplm_as_cib_gm_dv'::name])) 
            AND n.schema_src_id !~~ '%_ld_%'::text 
            -- !! AND n.schema_src_id !~~ '%_stg_%'::text
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'plan_';

CREATE TEMPORARY TABLE plan_0 AS 
         SELECT 
            n.schema_src_id,
            n.node_src_id,
            n.node_type_src_id,
            n.is_active,
            n.node_type_cd,
            n.scheduler_id,
            n.scheduler_type_src_id,
            n.period_type_id,
            n.every_times,
            n.period_type_comment,
            n.period_refresh_comment,
            n.user_refresh,
            dg_full.meta_match(now(), COALESCE(n.period_type_comment, '0 12 * * 1-5'::text)) AS now_period_type_match,
            n.gregor_dt AS plan_,
            dg_full.meta_match(n.gregor_dt::timestamp with time zone, COALESCE(n.period_type_comment, '0 12 * * 1-5'::text)) AS calendar_period_type_match,
            n.src_cd,
            n.pt_descr,
            n.is_wf_time_sched_active
           FROM plan_ n
          WHERE 1 = 1 
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'plan_0';

CREATE TEMPORARY TABLE plan_1 AS 
         SELECT 
            c.schema_src_id::text AS schema_src_id,
            c.node_src_id::text AS node_src_id,
            c.scheduler_id,
            c.scheduler_type_src_id,
            c.node_type_src_id,
            c.period_type_id,
            c.period_type_comment,
            c.period_refresh_comment,
            c.now_period_type_match,
            c.plan_ AS plan_cron, -- план по cron
            c.every_times,
            c.src_cd,
            c.pt_descr,
            c.plan_,
            c.calendar_period_type_match,
            c.is_wf_time_sched_active
           FROM plan_0 c
          WHERE 1 = 1 
            AND c.calendar_period_type_match IS TRUE
            AND c.plan_::date <= ('now'::text::date + '7 days'::interval)
DISTRIBUTED BY (schema_src_id, node_src_id);
RAISE NOTICE 'plan_1';

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'temp_meta_scheduler_plan - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE temp_meta_scheduler_plan
AS 
 SELECT  
    c1.schema_src_id::text,
    c1.node_src_id::text,
    c1.scheduler_type_src_id::varchar(250),
    c1.node_type_src_id::int4,
    c1.period_type_id,
    c1.period_type_comment::text,
    c1.period_refresh_comment::text,
    now() AS now_,
    c1.now_period_type_match,
    c1.plan_,
    COALESCE(lead(c1.plan_) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '2999-12-31 00:00:00'::timestamp without time zone) + '00:00:01'::interval AS plan_next,
    c1.plan_::timestamp with time zone - now() AS now_plan_diff,
    c1.pt_descr::varchar(250),
    c1.every_times::int4,
    c1.plan_::date AS plan_dt,
    COALESCE(lead(c1.plan_::date) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '2999-12-31'::date) - '1 day'::interval AS plan_dt_next,
    COALESCE(lag(c1.plan_::date) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '1900-01-01'::date) + '1 day'::interval AS plan_dt_prev,
    COALESCE(lag(c1.plan_) OVER (PARTITION BY c1.node_type_src_id, c1.schema_src_id, c1.node_src_id ORDER BY c1.plan_), '1900-01-01 00:00:00'::timestamp without time zone) + '00:00:01'::interval AS plan_prev,
    c1.scheduler_id,
    c1.src_cd::TEXT,
    c1.is_wf_time_sched_active
   FROM plan_1 c1
  WHERE 1 = 1
DISTRIBUTED BY (schema_src_id, node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE temp_meta_scheduler_plan;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'temp_meta_scheduler_plan - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

DROP TABLE IF EXISTS pl_;
DROP TABLE IF EXISTS plan_;
DROP TABLE IF EXISTS plan_0;
DROP TABLE IF EXISTS plan_1;
DROP TABLE IF EXISTS min15;

/*Очистка 2*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_scheduler_plan';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_scheduler_plan;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_scheduler_plan'|| chr(9) || v_deleted_row::text;


/*Добавление новых данных 2*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_scheduler_plan ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_scheduler_plan 
(
    schema_src_id ,
    node_src_id ,
    scheduler_type_src_id ,
    node_type_src_id ,
    period_type_id ,
    period_type_comment ,
    period_refresh_comment ,
    now_ ,
    now_period_type_match ,
    plan_ ,
    plan_next ,
    now_plan_diff ,
    pt_descr ,
    every_times ,
    plan_dt ,
    plan_dt_next ,
    plan_dt_prev ,
    plan_prev ,
    scheduler_id ,
    is_wf_time_sched_active,
    src_cd ,
    load_dttm ,
    wf_load_id ,
    eff_from_dttm ,
    eff_to_dttm ,
    last_seen_dttm 
    )
SELECT  
    t.schema_src_id,
    t.node_src_id,
    t.scheduler_type_src_id,
    t.node_type_src_id,
    t.period_type_id,
    t.period_type_comment,
    t.period_refresh_comment,
    t.now_,
    t.now_period_type_match,
    t.plan_,
    t.plan_next,
    t.now_plan_diff,
    t.pt_descr,
    t.every_times,
    t.plan_dt,
    t.plan_dt_next,
    t.plan_dt_prev,
    t.plan_prev,
    t.scheduler_id,
    t.is_wf_time_sched_active,
    t.src_cd,
    current_timestamp AS load_dttm,
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    current_timestamp AS last_seen_dttm
FROM temp_meta_scheduler_plan t;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_scheduler_plan' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_scheduler_plan - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS temp_meta_scheduler_plan;

v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;

















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph(p_target_node_id text, p_ctl_flg int4)
	RETURNS text
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
DECLARE
    v_params          text default '';
    v_res_statements  text default '';

    v_sql           text := '';
    v_out_graphviz  text := '';
    tt  record;
    num int4;
BEGIN
    /* Добавить логгирование  */
    v_params := format('p_target_node_id = %I , p_ctl_flg = %I', 
                        p_target_node_id  , p_ctl_flg 
                      );
       
    /* Временная таблица с выстроенной иерархией */
    v_sql := FORMAT( '
    create temporary table temp_sql as     
with recursive search_graph (
  src_schema_src_id , src_node_src_id 
, target_schema_src_id , target_node_src_id
, src_node_id 
, target_node_id
, weight 
, edge_type_cd
, depth
, path
, cycle
) as 
(
select 
  g.src_schema_src_id 
, g.src_node_src_id 
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, 1::int4 as depth
, array[g.target_schema_src_id  || ''_'' ||  g.target_node_src_id,g.src_schema_src_id  || ''_'' ||  g.src_node_src_id]
, false
from dg_full.meta_edge_link g
where 1=1
  and g.is_active = true
  and g.target_schema_src_id ||''.''||g.target_node_src_id = ''%1$s'' 
union all
select 
  g.src_schema_src_id 
, g.src_node_src_id
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, sg.depth + 1::int4 as depth
, path || (g.src_schema_src_id  || ''_'' ||  g.src_node_src_id)::text
, g.src_schema_src_id  || ''_'' ||  g.src_node_src_id = any(path)
from dg_full.meta_edge_link g, search_graph sg
where 1=1
and g.is_active = true
and g.target_schema_src_id ||''_''|| g.target_node_src_id = sg.src_schema_src_id || ''_'' || sg.src_node_src_id
and not cycle
)
select distinct
  sg1.src_schema_src_id
, ss.descr as ss_descr
, ss."type" as ss_type
, ss.schema_type as ss_schema_type
, ss.src_cd as ss_src_cd
, sg1.src_node_src_id
, sn.node_type_src_id as snt_node_type_src_id
, sn.node_type_cd as snt_node_type_cd
, sg1.target_schema_src_id
, ts."type" as ts_type
, ts.schema_type as ts_schema_type
, ts.src_cd as ts_src_cd
, ts.descr as ts_descr
, sg1.target_node_src_id
, tn.node_type_src_id as tnt_node_type_src_id
, tn.node_type_cd as tnt_node_type_cd
, sg1.src_node_id, sg1.target_node_id, sg1.weight, sg1.edge_type_cd
, sg1.depth, sg1.path, sg1.cycle
, sn.src_cd as sn_src_cd -- 
, tn.src_cd as tn_src_cd -- 
, (COALESCE(src_o.property_val::int,0) + COALESCE(tgt_o.property_val::int,0) + case when sn.src_cd <> ''GP'' or tn.src_cd <> ''GP'' then 1 else 0 end) AS is_active_objects
from search_graph sg1 
join dg_full.meta_schema_ref_table ss on sg1.src_schema_src_id = ss.schema_src_id 
join dg_full.meta_schema_ref_table ts on sg1.target_schema_src_id = ts.schema_src_id 
left join dg_full.meta_node_ref_table sn on row(sg1.src_schema_src_id , sg1.src_node_src_id) = row(sn.schema_src_id , sn.node_src_id) and sn.is_active = true
left join dg_full.meta_node_ref_table tn on row(sg1.target_schema_src_id , sg1.target_node_src_id) = row(tn.schema_src_id , tn.node_src_id) and tn.is_active = true
LEFT JOIN dg_full.vmeta_property_hsat src_o ON src_o.property_type_src_id = 6 AND src_o.schema_src_id = sg1.src_schema_src_id    AND src_o.object_src_id  = sg1.src_node_src_id
LEFT JOIN dg_full.vmeta_property_hsat tgt_o ON tgt_o.property_type_src_id = 6 AND tgt_o.schema_src_id = sg1.target_schema_src_id AND tgt_o.object_src_id  = sg1.target_node_src_id
 distributed by (src_node_id)       ',
    p_target_node_id -- 1
    );
    v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || v_sql;

    EXECUTE v_sql;
   
    analyze temp_sql;
   
    /* Построение объекта Graphviz */
    v_out_graphviz := 'digraph G { ' || chr(10)
                    || 'graph [pack=true rankdir=LR bgcolor=transparent fontname=Helvetica fontsize=10];' || chr(10)
                    || 'node [fixedsize=shape margin="0.1,0.1" style=rounded fontname=Helvetica fontsize=10];' || chr(10)
                    || 'edge [fontname=Helvetica fontsize=11 color=gray50 fontcolor=gray50];' || chr(10) || chr(10);
    -- Node   
    FOR tt IN (SELECT DISTINCT  
                     replace(replace(replace(src_node_id,'://','_'),'/','_'),' ','_') as w1,
                     src_schema_src_id as w2,
                     src_node_src_id   as w3,
                     snt_node_type_cd  as w4 
                     FROM temp_sql 
                     WHERE is_active_objects >= 1
                UNION   
                SELECT DISTINCT  
                     replace(replace(replace(target_node_id,'://','_'),'/','_'),' ','_') as w1,
                     target_schema_src_id as w2,
                     target_node_src_id as w3,
                     tnt_node_type_cd as w4 
                    FROM temp_sql
                    WHERE is_active_objects >= 1    
                order by w1
              ) 
       loop
        v_out_graphviz := v_out_graphviz || tt.w1 || '[' ||
                                                     case when (tt.w2 like 's_grnplm_ld%' and tt.w2 not like '%_dm') then 'color=red   '
                                                          when (tt.w2 like 's_grnplm_ld%' and tt.w2 like '%_dm') then 'color=yellow   '
                                                          when tt.w2 like 's_grnplm_as%' then 'color=green  '
                                                          else 'color=black   '
                                                     end ||     
                                            case when tt.w4 = 'Task' then 'fillcolor=yellow50 ' else '' end ||         
                                            case when tt.w4 = 'Entity' then 'shape=circle   width=0.3   fixedsize=shape margin=0  ' 
                                                 else 'shape=record  ' 
                                            end ||
                                            case when tt.w4 = 'Entity' then ' label="'|| tt.w3 || '"'
                                                 else ' label="{'|| COALESCE(tt.w2,'') || '|' || COALESCE(tt.w3,'') || '|' || COALESCE(tt.w4,'') || '}"'  
                                            end || '];' || chr(10);
    end loop;
   -- Edge
    for tt in (select distinct 
                      replace(replace(replace(src_node_id,'://','_'),'/','_'),' ','_') as w1,
                      replace(replace(replace(target_node_id,'://','_'),'/','_'),' ','_') as w2 ,
                      edge_type_cd as w3 
               from temp_sql 
               where 1=1
               AND is_active_objects >= 1
               AND ((case when p_ctl_flg = 1 then 'CTL' else '1' end = case when p_ctl_flg = 1 then sn_src_cd else '1' end )
                 or (case when p_ctl_flg = 1 then 'CTL' else '1' end = case when p_ctl_flg = 1 then tn_src_cd else '1' end ))
               --order by depth, src_node_id, target_node_id
               )
    loop
        v_out_graphviz := v_out_graphviz || COALESCE(tt.w1,'') || ' -> ' || COALESCE(tt.w2,'') || '[label="' || COALESCE(tt.w3,'') || '"]' || ';' || chr(10);
    end loop;
    v_out_graphviz := v_out_graphviz || '}';
   
       v_res_statements := v_res_statements || chr(10) || '/* Out graphviz: */'|| chr(10) || v_out_graphviz;
       perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, 'return_meta_search_graph' , -1, -1);

      drop table temp_sql;
      RETURN v_out_graphviz;
   
exception
       when others then
            perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLSTATE||'::'||SQLERRM, v_params, 'return_meta_search_graph', -1, -1);
            raise exception '(%:%:%:%)', v_params, v_res_statements, sqlstate, sqlerrm;

END;




























$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_fields(in p_target_node_id text, in p_ctl_flg int4, stbl text, sfields text, sdescription text, sassociation text)
	RETURNS TABLE (stbl text, sfields text, sdescription text, sassociation text)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
    
    
DECLARE
    v_params          text default '';
    v_res_statements  text default '';

    v_sql           text := '';
    v_out_graphviz  text := '';
    tt  record;
    num int4;
BEGIN
    /* Добавить логгирование  */
    v_params := format('p_target_node_id = %I , p_ctl_flg = %I', 
                        p_target_node_id  , p_ctl_flg 
                      );
       
    /* Временная таблица с выстроенной иерархией */
    v_sql := FORMAT( '
with recursive search_graph (
  src_schema_src_id , src_node_src_id 
, target_schema_src_id , target_node_src_id
, src_node_id 
, target_node_id
, weight 
, edge_type_cd
, depth
, path
, cycle
) as 
(
select 
  g.src_schema_src_id 
, g.src_node_src_id 
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, 1::int4 as depth
, array[g.target_schema_src_id  || ''_'' ||  g.target_node_src_id,g.src_schema_src_id  || ''_'' ||  g.src_node_src_id]
, false
from dg_full.meta_edge_link g
where 1=1
  and g.is_active = true
  and g.target_schema_src_id ||''.''||g.target_node_src_id = ''%1$s'' 
union all
select 
  g.src_schema_src_id 
, g.src_node_src_id
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, sg.depth + 1::int4 as depth
, path || (g.src_schema_src_id  || ''_'' ||  g.src_node_src_id)::text
, g.src_schema_src_id  || ''_'' ||  g.src_node_src_id = any(path)
from dg_full.meta_edge_link g, search_graph sg
where 1=1
and g.is_active = true
and g.target_schema_src_id ||''_''|| g.target_node_src_id = sg.src_schema_src_id || ''_'' || sg.src_node_src_id
and not cycle
)
, temp_step_1 as (
select distinct
  sg.src_schema_src_id
, ss.descr as ss_descr
, ss."type" as ss_type
, ss.schema_type as ss_schema_type
, ss.src_cd as ss_src_cd
, sg.src_node_src_id
, sn.node_type_src_id as snt_node_type_src_id
, sn.node_type_cd as snt_node_type_cd
, sg.target_schema_src_id
, ts."type" as ts_type
, ts.schema_type as ts_schema_type
, ts.src_cd as ts_src_cd
, ts.descr as ts_descr
, sg.target_node_src_id
, tn.node_type_src_id as tnt_node_type_src_id
, tn.node_type_cd as tnt_node_type_cd
, sg.src_node_id, sg.target_node_id, sg.weight, sg.edge_type_cd
, sg.depth, sg.path, sg.cycle
, sn.src_cd as sn_src_cd -- 
, tn.src_cd as tn_src_cd -- 
from search_graph sg 
join dg_full.meta_schema_ref_table ss on sg.src_schema_src_id = ss.schema_src_id 
join dg_full.meta_schema_ref_table ts on sg.target_schema_src_id = ts.schema_src_id 
left join dg_full.meta_node_ref_table sn on row(sg.src_schema_src_id , sg.src_node_src_id) = row(sn.schema_src_id , sn.node_src_id) and sn.is_active = true
left join dg_full.meta_node_ref_table tn on row(sg.target_schema_src_id , sg.target_node_src_id) = row(tn.schema_src_id , tn.node_src_id) and tn.is_active = true
)
, temp_step_2 as (
select distinct 
          replace(replace(replace(src_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
          replace(replace(replace(target_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w2 ,
          edge_type_cd as w3 
from temp_step_1
)
select 
qq.w2::text as sTbl ,
qq.w1::text as sFields ,
null::text as sDescription ,
qq.w1::text as sAssociation
from temp_step_2 qq
',
    p_target_node_id -- 1
    );
    v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || v_sql;

return query
EXECUTE v_sql;
   
       perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, 'return_meta_search_graph_fields' , -1, -1);

exception
       when others then
            perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLSTATE||'::'||SQLERRM, v_params, 'return_meta_search_graph_fields', -1, -1);
            raise exception '(%:%:%:%)', v_params, v_res_statements, sqlstate, sqlerrm;

END;




$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_import_fields(in p_target_node_id text, in p_ctl_flg int4, stablename text, sfieldname text)
	RETURNS TABLE (stablename text, sfieldname text)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
    
    
DECLARE
    v_params          text default '';
    v_res_statements  text default '';

    v_sql           text := '';
    v_out_graphviz  text := '';
    tt  record;
    num int4;
BEGIN
    /* Добавить логгирование  */
    v_params := format('p_target_node_id = %I , p_ctl_flg = %I', 
                        p_target_node_id  , p_ctl_flg 
                      );
       
    /* Временная таблица с выстроенной иерархией */
    v_sql := FORMAT( '
with recursive search_graph (
  src_schema_src_id , src_node_src_id 
, target_schema_src_id , target_node_src_id
, src_node_id 
, target_node_id
, weight 
, edge_type_cd
, depth
, path
, cycle
) as 
(
select 
  g.src_schema_src_id 
, g.src_node_src_id 
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, 1::int4 as depth
, array[g.target_schema_src_id  || ''_'' ||  g.target_node_src_id,g.src_schema_src_id  || ''_'' ||  g.src_node_src_id]
, false
from dg_full.meta_edge_link g
where 1=1
  and g.is_active = true
  and g.target_schema_src_id ||''.''||g.target_node_src_id = ''%1$s'' 
union all
select 
  g.src_schema_src_id 
, g.src_node_src_id
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, sg.depth + 1::int4 as depth
, path || (g.src_schema_src_id  || ''_'' ||  g.src_node_src_id)::text
, g.src_schema_src_id  || ''_'' ||  g.src_node_src_id = any(path)
from dg_full.meta_edge_link g, search_graph sg
where 1=1
and g.is_active = true
and g.target_schema_src_id ||''_''|| g.target_node_src_id = sg.src_schema_src_id || ''_'' || sg.src_node_src_id
and not cycle
)
, temp_step_1 as (
select distinct
  sg.src_schema_src_id
, ss.descr as ss_descr
, ss."type" as ss_type
, ss.schema_type as ss_schema_type
, ss.src_cd as ss_src_cd
, sg.src_node_src_id
, sn.node_type_src_id as snt_node_type_src_id
, sn.node_type_cd as snt_node_type_cd
, sg.target_schema_src_id
, ts."type" as ts_type
, ts.schema_type as ts_schema_type
, ts.src_cd as ts_src_cd
, ts.descr as ts_descr
, sg.target_node_src_id
, tn.node_type_src_id as tnt_node_type_src_id
, tn.node_type_cd as tnt_node_type_cd
, sg.src_node_id, sg.target_node_id, sg.weight, sg.edge_type_cd
, sg.depth, sg.path, sg.cycle
, sn.src_cd as sn_src_cd -- 
, tn.src_cd as tn_src_cd -- 
from search_graph sg 
join dg_full.meta_schema_ref_table ss on sg.src_schema_src_id = ss.schema_src_id 
join dg_full.meta_schema_ref_table ts on sg.target_schema_src_id = ts.schema_src_id 
left join dg_full.meta_node_ref_table sn on row(sg.src_schema_src_id , sg.src_node_src_id) = row(sn.schema_src_id , sn.node_src_id) and sn.is_active = true
left join dg_full.meta_node_ref_table tn on row(sg.target_schema_src_id , sg.target_node_src_id) = row(tn.schema_src_id , tn.node_src_id) and tn.is_active = true
)
, temp_step_2 as (
select distinct 
          replace(replace(replace(src_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
          replace(replace(replace(target_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w2 ,
          edge_type_cd as w3 
from temp_step_1
union 
select distinct 
          replace(replace(replace(target_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
          replace(replace(replace(target_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w2 ,
          edge_type_cd as w3 
from temp_step_1
)
select 
qq.w2::text as sTableName,
qq.w1::text as sFieldName
from temp_step_2 qq
',
    p_target_node_id -- 1
    );
    v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || v_sql;

return query
EXECUTE v_sql;
   
       perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, 'return_meta_search_graph_import_fields' , -1, -1);

exception
       when others then
            perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLSTATE||'::'||SQLERRM, v_params, 'return_meta_search_graph_import_fields', -1, -1);
            raise exception '(%:%:%:%)', v_params, v_res_statements, sqlstate, sqlerrm;

END;




$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_list_objects_for_dm(in p_target_node_id text, in p_ctl_flg int4, stbl text, stags text, sdistributedby text, sdatastoragemode text, dtlast timestamp)
	RETURNS TABLE (stbl text, stags text, sdistributedby text, sdatastoragemode text, dtlast timestamp)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
    
    
    
    
    
    
    
    
    
DECLARE
    v_params          text default '';
    v_res_statements  text default '';

    v_sql           text := '';
    v_out_graphviz  text := '';
    tt  record;
    num int4;
BEGIN
    /* Добавить логгирование  */
    v_params := format('p_target_node_id = %I , p_ctl_flg = %I', 
                        p_target_node_id  , p_ctl_flg 
                      );
       
    /* Временная таблица с выстроенной иерархией */
    v_sql := FORMAT( '
with recursive search_graph (
  src_schema_src_id , src_node_src_id 
, target_schema_src_id , target_node_src_id
, src_node_id 
, target_node_id
, weight 
, edge_type_cd
, depth
, path
, cycle
) as 
(
select 
  g.src_schema_src_id 
, g.src_node_src_id 
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, 1::int4 as depth
, array[g.target_schema_src_id  || ''_'' ||  g.target_node_src_id,g.src_schema_src_id  || ''_'' ||  g.src_node_src_id]
, false
from dg_full.meta_edge_link g
where 1=1
  and g.is_active = true
  and g.target_schema_src_id ||''.''||g.target_node_src_id = ''%1$s'' 
union all
select 
  g.src_schema_src_id 
, g.src_node_src_id
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, sg.depth + 1::int4 as depth
, path || (g.src_schema_src_id  || ''_'' ||  g.src_node_src_id)::text
, g.src_schema_src_id  || ''_'' ||  g.src_node_src_id = any(path)
from dg_full.meta_edge_link g, search_graph sg
where 1=1
and g.is_active = true
and g.target_schema_src_id ||''_''|| g.target_node_src_id = sg.src_schema_src_id || ''_'' || sg.src_node_src_id
and not cycle
)
, temp_step_1 as (
select distinct
  sg.src_schema_src_id
, ss.descr as ss_descr
, ss."type" as ss_type
, ss.schema_type as ss_schema_type
, ss.src_cd as ss_src_cd
, sg.src_node_src_id
, sn.node_type_src_id as snt_node_type_src_id
, sn.node_type_cd as snt_node_type_cd
, sg.target_schema_src_id
, ts."type" as ts_type
, ts.schema_type as ts_schema_type
, ts.src_cd as ts_src_cd
, ts.descr as ts_descr
, sg.target_node_src_id
, tn.node_type_src_id as tnt_node_type_src_id
, tn.node_type_cd as tnt_node_type_cd
, sg.src_node_id, sg.target_node_id, sg.weight, sg.edge_type_cd
, sg.depth, sg.path, sg.cycle
, sn.src_cd as sn_src_cd -- 
, tn.src_cd as tn_src_cd -- 
, (COALESCE(src_o.property_val::int,0) + COALESCE(tgt_o.property_val::int,0) + case when sn.src_cd <> ''GP'' or tn.src_cd <> ''GP'' then 1 else 0 end) AS is_active_objects
, src_dk.distribution_keys as src_dk
, tgt_dk.distribution_keys as target_dk
, src_dk.data_storage_mode as src_dsm
, tgt_dk.data_storage_mode as target_dsm
from search_graph sg 
join dg_full.meta_schema_ref_table ss on sg.src_schema_src_id = ss.schema_src_id 
join dg_full.meta_schema_ref_table ts on sg.target_schema_src_id = ts.schema_src_id 
left join dg_full.meta_node_ref_table sn on row(sg.src_schema_src_id , sg.src_node_src_id) = row(sn.schema_src_id , sn.node_src_id) and sn.is_active = true
left join dg_full.meta_node_ref_table tn on row(sg.target_schema_src_id , sg.target_node_src_id) = row(tn.schema_src_id , tn.node_src_id) and tn.is_active = true
LEFT JOIN dg_full.vmeta_property_hsat src_o ON src_o.property_type_src_id = 6 AND src_o.schema_src_id = sg.src_schema_src_id    AND src_o.object_src_id  = sg.src_node_src_id
LEFT JOIN dg_full.vmeta_property_hsat tgt_o ON tgt_o.property_type_src_id = 6 AND tgt_o.schema_src_id = sg.target_schema_src_id AND tgt_o.object_src_id  = sg.target_node_src_id
LEFT JOIN dg_full.vmeta_get_distribution_key src_dk ON  src_dk.schema_name = sg.src_schema_src_id AND src_dk.table_name  = sg.src_node_src_id
LEFT JOIN dg_full.vmeta_get_distribution_key tgt_dk ON  tgt_dk.schema_name = sg.target_schema_src_id AND tgt_dk.table_name  = sg.target_node_src_id
 )
, temp_step_2 as (
select distinct 
                     replace(replace(replace(src_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
                     src_schema_src_id as w2,
                     src_node_src_id   as w3,
                     snt_node_type_cd  as w4,
                     src_dk as w5,
                     src_dsm as w6
                     from temp_step_1 
                     WHERE is_active_objects >= 1
                union 
                select distinct 
                     replace(replace(replace(target_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
                     target_schema_src_id as w2,
                     target_node_src_id as w3,
                     tnt_node_type_cd as w4,
                     target_dk as w5,
                     target_dsm as w6 
                    from temp_step_1
                    WHERE is_active_objects >= 1
)
select 
    qq.w1::text as sTbl,    
    qq.w4::text as sTags,
    qq.w5::text as sDistributedBy,
    qq.w6::text as sDataStorageMode,  
    current_timestamp::timestamp as dtLast
from temp_step_2 qq
;       ',
    p_target_node_id -- 1
    );
    v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || v_sql;

    return query
    EXECUTE v_sql;
   
   perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, 'return_meta_search_graph_list_objects_for_dm' , -1, -1);

--        drop table temp_sql;
   
exception
       when others then
            perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLSTATE||'::'||SQLERRM, v_params, 'return_meta_search_graph_list_objects_for_dm', -1, -1);
            raise exception '(%:%:%:%)', v_params, v_res_statements, sqlstate, sqlerrm;

END;












$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_tables(in p_target_node_id text, in p_ctl_flg int4, stbl text, stable_type text, smain_source text, sprimary_key text, stags text, saux_sources text, sdescription text, sprefix text)
	RETURNS TABLE (stbl text, stable_type text, smain_source text, sprimary_key text, stags text, saux_sources text, sdescription text, sprefix text)
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
    
    
    
DECLARE
    v_params          text default '';
    v_res_statements  text default '';

    v_sql           text := '';
    v_out_graphviz  text := '';
    tt  record;
    num int4;
BEGIN
    /* Добавить логгирование  */
    v_params := format('p_target_node_id = %I , p_ctl_flg = %I', 
                        p_target_node_id  , p_ctl_flg 
                      );
       
    /* Временная таблица с выстроенной иерархией */
    v_sql := FORMAT( '
with recursive search_graph (
  src_schema_src_id , src_node_src_id 
, target_schema_src_id , target_node_src_id
, src_node_id 
, target_node_id
, weight 
, edge_type_cd
, depth
, path
, cycle
) as 
(
select 
  g.src_schema_src_id 
, g.src_node_src_id 
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, 1::int4 as depth
, array[g.target_schema_src_id  || ''_'' ||  g.target_node_src_id,g.src_schema_src_id  || ''_'' ||  g.src_node_src_id]
, false
from dg_full.meta_edge_link g
where 1=1
  and g.is_active = true
  and g.target_schema_src_id ||''.''||g.target_node_src_id = ''%1$s'' 
union all
select 
  g.src_schema_src_id 
, g.src_node_src_id
, g.target_schema_src_id 
, g.target_node_src_id
, g.src_schema_src_id || ''_'' || g.src_node_src_id  as src_node_id
, g.target_schema_src_id || ''_'' || g.target_node_src_id as target_node_id
, g.weight 
, g.edge_type_cd
, sg.depth + 1::int4 as depth
, path || (g.src_schema_src_id  || ''_'' ||  g.src_node_src_id)::text
, g.src_schema_src_id  || ''_'' ||  g.src_node_src_id = any(path)
from dg_full.meta_edge_link g, search_graph sg
where 1=1
and g.is_active = true
and g.target_schema_src_id ||''_''|| g.target_node_src_id = sg.src_schema_src_id || ''_'' || sg.src_node_src_id
and not cycle
)
, temp_step_1 as (
select distinct
  sg.src_schema_src_id
, ss.descr as ss_descr
, ss."type" as ss_type
, ss.schema_type as ss_schema_type
, ss.src_cd as ss_src_cd
, sg.src_node_src_id
, sn.node_type_src_id as snt_node_type_src_id
, sn.node_type_cd as snt_node_type_cd
, sg.target_schema_src_id
, ts."type" as ts_type
, ts.schema_type as ts_schema_type
, ts.src_cd as ts_src_cd
, ts.descr as ts_descr
, sg.target_node_src_id
, tn.node_type_src_id as tnt_node_type_src_id
, tn.node_type_cd as tnt_node_type_cd
, sg.src_node_id, sg.target_node_id, sg.weight, sg.edge_type_cd
, sg.depth, sg.path, sg.cycle
, sn.src_cd as sn_src_cd -- 
, tn.src_cd as tn_src_cd -- 
from search_graph sg 
join dg_full.meta_schema_ref_table ss on sg.src_schema_src_id = ss.schema_src_id 
join dg_full.meta_schema_ref_table ts on sg.target_schema_src_id = ts.schema_src_id 
left join dg_full.meta_node_ref_table sn on row(sg.src_schema_src_id , sg.src_node_src_id) = row(sn.schema_src_id , sn.node_src_id) and sn.is_active = true
left join dg_full.meta_node_ref_table tn on row(sg.target_schema_src_id , sg.target_node_src_id) = row(tn.schema_src_id , tn.node_src_id) and tn.is_active = true
 )
, temp_step_2 as (
select distinct 
                     replace(replace(replace(src_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
                     src_schema_src_id as w2,
                     src_node_src_id   as w3,
                     snt_node_type_cd  as w4 
                     from temp_step_1 
                union 
                select distinct 
                     replace(replace(replace(target_node_id,''://'',''_''),''/'',''_''),'' '',''_'') as w1,
                     target_schema_src_id as w2,
                     target_node_src_id as w3,
                     tnt_node_type_cd as w4 
                    from temp_step_1
)
select 
    qq.w1::text as sTbl,    
    null::text as sTable_Type,
    ''ПКАП''::text as sMain_Source, 
    qq.w1::text as sPrimary_Key,
    qq.w4::text as sTags,
    null::text as sAux_Sources,
    null::text as sDescription,
    null::text as sPrefix
from temp_step_2 qq
;       ',
    p_target_node_id -- 1
    );
    v_res_statements := v_res_statements || chr(10) || '/* Create script: */'|| chr(10) || v_sql;

    return query
    EXECUTE v_sql;
   
   perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, 'return_meta_search_graph_tables' , -1, -1);

--        drop table temp_sql;
   
exception
       when others then
            perform s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLSTATE||'::'||SQLERRM, v_params, 'return_meta_search_graph_tables', -1, -1);
            raise exception '(%:%:%:%)', v_params, v_res_statements, sqlstate, sqlerrm;

END;





$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_target_all_obj(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
	
	
	
	
	
	
	
	
    
    
    
    
    
    
    
    
    

/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-04-14 Devide recursive by sources
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_search_graph_target_all_obj';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_search_graph_target_all_obj';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;
rec            record;
row_cn        INTEGER := 1; -- Переменная для подсчета прохода циклов

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_gr - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_gr AS 
         SELECT DISTINCT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd,
            g.src_schema_src_id::text || '||'::text || g.src_node_src_id::text AS src_node_id,
            g.target_schema_src_id::text || '||'::text || g.target_node_src_id::text AS target_node_id,
            g.src_cd 
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1
           AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
DISTRIBUTED BY (src_node_id, target_node_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_gr;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_gr - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

-------------------------------------------------------------------

CREATE TEMPORARY TABLE tmp_gr_filtered1 AS 
SELECT * 
FROM tmp_gr
 WHERE 1 = 1
   AND tgt_node_type_cd IN  ('Flow', 'Entity', 'TFS') --  'Table', 'View', 'Application'
 DISTRIBUTED BY (src_node_id, target_node_id); 


CREATE INDEX ON tmp_gr_filtered1 (target_schema_src_id, target_node_src_id, tgt_node_type_cd );
CREATE INDEX ON tmp_gr_filtered1 (src_node_id);


-- tmp_target_CTL
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_target_CTL - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_target_CTL AS
WITH RECURSIVE search_graph
(src_schema_src_id, src_node_src_id, src_node_type_cd ,
 target_schema_src_id, target_node_src_id, tgt_node_type_cd,
 depth, path, cycle, 
 root_schema_src_id, root_node_src_id, root_node_type_cd,
 src_node_id, target_node_id,
 src_cd
 ) AS (
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_node_id::TEXT, 
            g.target_node_id::TEXT,
            g.src_cd
         FROM tmp_gr_filtered1 g
        UNION ALL
         SELECT 
            nxt.src_schema_src_id::text,
            nxt.src_node_src_id::text,
            nxt.src_node_type_cd,
            nxt.target_schema_src_id::text,
            nxt.target_node_src_id::text,
            nxt.tgt_node_type_cd ,
            prv.depth + 1 AS depth,
            prv.path || nxt.src_node_id::text,
            nxt.src_node_id::text = ANY (prv.path),
            prv.root_schema_src_id::text,
            prv.root_node_src_id::TEXT,
            prv.root_node_type_cd,
            prv.src_node_id::TEXT , 
            nxt.target_node_id::TEXT ,
            nxt.src_cd
         FROM search_graph prv
         JOIN tmp_gr_filtered1 nxt 
----           ON prv.src_node_id::text = nxt.target_node_id::text
           ON prv.src_schema_src_id  = nxt.target_schema_src_id  
          AND prv.src_node_src_id  = nxt.target_node_src_id 
          AND prv.src_node_type_cd = nxt.tgt_node_type_cd  
         WHERE 1 = 1 
           AND NOT prv.CYCLE
           AND prv.DEPTH < 20
        )
   SELECT 
      h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd, 
      h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd ,
      h.depth, 
      h.root_schema_src_id, 
      h.root_node_src_id,
      h.root_node_type_cd,
      h.src_cd
   FROM search_graph h
   WHERE 1=1
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_target_CTL;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_target_CTL - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

----------------------------------------------
CREATE TEMPORARY TABLE tmp_gr_filtered AS 
SELECT * 
FROM tmp_gr
 WHERE 1 = 1
  AND tgt_node_type_cd IN  ('Table', 'View', 'Function') 
 DISTRIBUTED BY (src_node_id, target_node_id); 


CREATE INDEX ON tmp_gr_filtered (target_schema_src_id, target_node_src_id, tgt_node_type_cd );
CREATE INDEX ON tmp_gr_filtered (src_node_id);


-- tmp_target_GP
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_target_GP - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_target_GP AS
WITH RECURSIVE search_graph
(src_schema_src_id, src_node_src_id, src_node_type_cd ,
 target_schema_src_id, target_node_src_id, tgt_node_type_cd,
 depth, path, cycle, 
 root_schema_src_id, root_node_src_id, root_node_type_cd,
 src_node_id, target_node_id,
 src_cd
 ) AS (
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_node_id::TEXT, 
            g.target_node_id::TEXT,
            g.src_cd
         FROM tmp_gr_filtered g
        UNION ALL
         SELECT 
            nxt.src_schema_src_id::text,
            nxt.src_node_src_id::text,
            nxt.src_node_type_cd,
            nxt.target_schema_src_id::text,
            nxt.target_node_src_id::text,
            nxt.tgt_node_type_cd ,
            prv.depth + 1 AS depth,
            prv.path || nxt.src_node_id::text,
            nxt.src_node_id::text = ANY (prv.path),
            prv.root_schema_src_id::text,
            prv.root_node_src_id::TEXT,
            prv.root_node_type_cd,
            prv.src_node_id::TEXT , 
            nxt.target_node_id::TEXT ,
            nxt.src_cd
         FROM search_graph prv
         JOIN tmp_gr_filtered nxt 
----           ON prv.src_node_id::text = nxt.target_node_id::text
           ON prv.src_schema_src_id  = nxt.target_schema_src_id  
          AND prv.src_node_src_id  = nxt.target_node_src_id 
          AND prv.src_node_type_cd = nxt.tgt_node_type_cd  
         WHERE 1 = 1 
           AND NOT prv.CYCLE
           AND prv.DEPTH < 20
        )
   SELECT DISTINCT  
      h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd, 
      h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd ,
      h.depth, 
      h.root_schema_src_id, 
      h.root_node_src_id,
      h.root_node_type_cd,
      h.src_cd
   FROM search_graph h
   WHERE 1=1
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_target_GP;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_target_GP - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_gr_qs - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_gr_qs AS 
         SELECT DISTINCT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd,
            g.src_schema_src_id::text || '||'::text || g.src_node_src_id::text AS src_node_id,
            g.target_schema_src_id::text || '||'::text || g.target_node_src_id::text AS target_node_id,
            g.src_cd 
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1
           AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
DISTRIBUTED BY (target_schema_src_id  , target_node_src_id  ,tgt_node_type_cd)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_gr_qs;

CREATE INDEX ON tmp_gr_qs (target_schema_src_id, target_node_src_id, tgt_node_type_cd );
CREATE INDEX ON tmp_gr_qs (src_node_id);

v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_gr_qs - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_root_qs - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_root_qs  AS 
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_schema_src_id::text || '||'::text || g.src_node_src_id::text AS src_node_id,
            g.target_schema_src_id::text || '||'::text || g.target_node_src_id::text AS target_node_id,
            g.src_cd
          FROM dg_full.meta_edge_link g
          WHERE 1 = 1
           AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.tgt_node_type_cd IN  ('Dashboard QS', 'Application QS', 'SMD', 'Application Navi') 
           AND (g.target_schema_src_id, g.target_node_src_id, g.tgt_node_type_cd) NOT IN (SELECT s.src_schema_src_id, s.src_node_src_id, s.src_node_type_cd FROM tmp_gr s)
DISTRIBUTED BY (src_schema_src_id, src_node_src_id, src_node_type_cd )
;          
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_root_qs;

CREATE INDEX ON tmp_root_qs (target_schema_src_id, target_node_src_id, tgt_node_type_cd );
CREATE INDEX ON tmp_root_qs (src_node_id);
 
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_root_qs - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


-- tmp_target_QS0
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_target_QS0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
-- Создаем временную таблицу для накопления данных
CREATE TEMPORARY TABLE tmp_target_QS0 AS
SELECT 
    g.src_schema_src_id::text,
    g.src_node_src_id::text,
    g.src_node_type_cd,
    g.target_schema_src_id::text,
    g.target_node_src_id::text,
    g.tgt_node_type_cd,
    1 AS depth,
    ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
    false AS cycle,
    g.target_schema_src_id::text AS root_schema_src_id,
    g.target_node_src_id::text AS root_node_src_id,
    g.tgt_node_type_cd AS root_node_type_cd,
    g.src_node_id::TEXT,
    g.target_node_id::TEXT,
    g.src_cd
FROM tmp_root_qs g
DISTRIBUTED BY (src_schema_src_id, src_node_src_id,src_node_type_cd )
;

-- Выполняем цикл для обхода графа
row_cn := 1; -- Переменная для подсчета проходов цикла
BEGIN
    -- WHILE v_cnt > 0 LOOP
      WHILE row_cn < 7 LOOP
        -- Добавляем новый уровень вершин
        WITH new_nodes AS (
            SELECT 
                nxt.src_schema_src_id::text,
                nxt.src_node_src_id::text,
                nxt.src_node_type_cd,
                nxt.target_schema_src_id::text,
                nxt.target_node_src_id::text,
                nxt.tgt_node_type_cd,
                prv.depth + 1 AS depth,
                prv.path || nxt.src_node_id::TEXT AS path,
                nxt.src_node_id::text = ANY(prv.path) AS cycle,
                prv.root_schema_src_id::text,
                prv.root_node_src_id::TEXT,
                prv.root_node_type_cd,
                prv.src_node_id::TEXT,
                nxt.target_node_id::TEXT,
                nxt.src_cd
            FROM tmp_target_QS0 prv
            JOIN tmp_gr_qs nxt
              ON prv.src_schema_src_id = nxt.target_schema_src_id
             AND prv.src_node_src_id = nxt.target_node_src_id
             AND prv.src_node_type_cd = nxt.tgt_node_type_cd
             --LEFT JOIN tmp_gr_qs excl 
             -- ON prv.target_schema_src_id = excl.target_schema_src_id
             --AND prv.target_node_src_id = excl.target_node_src_id
             --AND prv.tgt_node_type_cd = excl.tgt_node_type_cd
            WHERE 1=1 
              AND NOT prv.CYCLE
              --AND excl.target_schema_src_id IS NULL 
        )
        INSERT INTO tmp_target_QS0
        SELECT * FROM new_nodes;
        
        -- Проверяем, сколько строк добавилось
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        row_cn := row_cn + 1; -- !!
        RAISE NOTICE 'tmp_target_QS0 - %, %:',row_cn, v_cnt;
    END LOOP;
END ;
RAISE NOTICE 'tmp_target_QS0';

-- Извлекаем результат из временной таблицы
CREATE TEMPORARY TABLE tmp_target_QS AS
SELECT 
    h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd,
    h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd,
    h.depth,
    h.root_schema_src_id,
    h.root_node_src_id,
    h.root_node_type_cd,
    h.src_cd
FROM tmp_target_QS0 h
DISTRIBUTED BY (src_schema_src_id, src_node_src_id,src_node_type_cd )
;


/*CREATE TEMPORARY TABLE tmp_target_QS AS
WITH RECURSIVE search_graph
(src_schema_src_id, src_node_src_id, src_node_type_cd ,
 target_schema_src_id, target_node_src_id, tgt_node_type_cd,
 depth, path, cycle, 
 root_schema_src_id, root_node_src_id, root_node_type_cd,
 src_node_id, target_node_id,
 src_cd
 ) AS (
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_node_id::TEXT, 
            g.target_node_id::TEXT,
            g.src_cd
         FROM tmp_root_qs g
         WHERE 1 = 1
        UNION ALL
         SELECT 
            nxt.src_schema_src_id::text,
            nxt.src_node_src_id::text,
            nxt.src_node_type_cd,
            nxt.target_schema_src_id::text,
            nxt.target_node_src_id::text,
            nxt.tgt_node_type_cd ,
            prv.depth + 1 AS depth,
            prv.path || nxt.src_node_id::text,
            nxt.src_node_id::text = ANY (prv.path),
            prv.root_schema_src_id::text,
            prv.root_node_src_id::TEXT,
            prv.root_node_type_cd,
            prv.src_node_id::TEXT , 
            nxt.target_node_id::TEXT ,
            nxt.src_cd
         FROM search_graph prv
         JOIN tmp_gr_qs nxt 
----           ON prv.src_node_id::text = nxt.target_node_id::text
           ON prv.src_schema_src_id  = nxt.target_schema_src_id  
          AND prv.src_node_src_id  = nxt.target_node_src_id 
          AND prv.src_node_type_cd = nxt.tgt_node_type_cd  
         WHERE 1 = 1 
           AND NOT prv.cycle
        )
   SELECT --DISTINCT  
      h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd, 
      h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd ,
      h.depth, 
      h.root_schema_src_id, 
      h.root_node_src_id,
      h.root_node_type_cd,
      h.src_cd
   FROM search_graph h
   WHERE 1=1
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;*/


GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_target_QS;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_target_QS - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

---------------------------------------------
/* Собираем цепочки из 3х источников - CTL\GP\QS */
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_search_graph - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_search_graph AS
SELECT DISTINCT 
t.*
FROM tmp_target_GP t
UNION ALL
SELECT *
FROM tmp_target_CTL 
UNION ALL
SELECT *
FROM tmp_target_QS
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_search_graph;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_search_graph - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_meta_search_graph_target_all_obj - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_meta_search_graph_target_all_obj AS 
WITH 
tmp_sql_2 AS ( /* SRC и TGT в один атрибут */
         SELECT 
--            replace(replace(replace(tmp_sql.src_node_id, '://'::text, '||'::text), '/'::text, '||'::text), ' '::text, '||'::text) AS node_id,
            tmp_sql.src_schema_src_id || '||' || tmp_sql.src_node_src_id   AS node_id,
            tmp_sql.src_schema_src_id::TEXT AS schema_src_id,
            tmp_sql.src_node_src_id::TEXT AS node_src_id,
            tmp_sql.src_node_type_cd AS node_type_cd,
            tmp_sql.depth,
            tmp_sql.root_schema_src_id || '||' || tmp_sql.root_node_src_id   AS root_node_id,
            tmp_sql.root_schema_src_id::TEXT,
            tmp_sql.root_node_src_id::TEXT,
            tmp_sql.root_node_type_cd,
            tmp_sql.src_cd
           FROM tmp_search_graph tmp_sql
        UNION ALL
         SELECT 
--            replace(replace(replace(tmp_sql.target_node_id, '://'::text, '||'::text), '/'::text, '||'::text), ' '::text, '||'::text) AS node_id,
            tmp_sql.target_schema_src_id || '||' || tmp_sql.target_node_src_id   AS node_id,
            tmp_sql.target_schema_src_id::TEXT AS schema_src_id,
            tmp_sql.target_node_src_id::TEXT AS node_src_id,
            tmp_sql.tgt_node_type_cd AS node_type_cd,
            tmp_sql.depth,
            tmp_sql.root_schema_src_id || '||' || tmp_sql.root_node_src_id   AS root_node_id,
            tmp_sql.root_schema_src_id::TEXT,
            tmp_sql.root_node_src_id::TEXT,
            tmp_sql.root_node_type_cd,
            tmp_sql.src_cd
           FROM tmp_search_graph tmp_sql
        )
 SELECT 
    tmp_sql_2.node_id::TEXT,
    tmp_sql_2.schema_src_id::text,
    tmp_sql_2.node_src_id::TEXT ,
    tmp_sql_2.node_type_cd::varchar(20),
    tmp_sql_2.src_cd::TEXT,
    min(tmp_sql_2.depth)::int4 AS depth,
    tmp_sql_2.root_node_id::TEXT,
    tmp_sql_2.root_schema_src_id::TEXT ,
    tmp_sql_2.root_node_src_id::TEXT ,
    tmp_sql_2.root_node_type_cd::varchar(20)
   FROM tmp_sql_2
  WHERE 1 = 1 AND tmp_sql_2.node_id !~~ '%_meta.%'::text
  GROUP BY 
           tmp_sql_2.node_id, 
           tmp_sql_2.schema_src_id,
           tmp_sql_2.node_src_id,
           tmp_sql_2.node_type_cd,
           tmp_sql_2.src_cd,
           tmp_sql_2.root_node_id, 
           tmp_sql_2.root_schema_src_id,
           tmp_sql_2.root_node_src_id,
           tmp_sql_2.root_node_type_cd
DISTRIBUTED BY (schema_src_id, node_src_id);
  
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_meta_search_graph_target_all_obj;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_meta_search_graph_target_all_obj - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_search_graph_target_all_obj';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_search_graph_target_all_obj;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_search_graph_target_all_obj'|| chr(9) || v_deleted_row::text;

/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_search_graph_target_all_obj ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_search_graph_target_all_obj 
(   
    node_id ,
    schema_src_id ,
    node_src_id ,
    node_type_cd ,
    src_cd ,
    "depth" ,
    root_node_id ,
    root_schema_src_id ,
    root_node_src_id ,
    root_node_type_cd ,
    load_dttm ,
    wf_load_id ,
    eff_from_dttm ,
    eff_to_dttm ,
    last_seen_dttm ,
    root_is_active,
    is_active
)
SELECT  
    t.node_id,
    t.schema_src_id ,
    t.node_src_id ,
    t.node_type_cd,
    t.src_cd,
    t.depth,
    t.root_node_id,
    t.root_schema_src_id ,
    t.root_node_src_id ,
    t.root_node_type_cd ,
    now() AS load_dttm,
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    n.is_active AS root_is_active,
    n1.is_active AS is_active
FROM tmp_meta_search_graph_target_all_obj t
LEFT JOIN dg_full.meta_node_ref_table n ON t.root_schema_src_id = n.schema_src_id AND t.root_node_id = n.node_src_id 
LEFT JOIN dg_full.meta_node_ref_table n1 ON t.schema_src_id = n1.schema_src_id AND t.node_src_id = n1.node_src_id
;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_search_graph_target_all_obj' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_search_graph_target_all_obj - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS tmp_meta_search_graph_target_all_obj;
DROP TABLE IF EXISTS tmp_search_graph;
DROP TABLE IF EXISTS tmp_target_GP;
DROP TABLE IF EXISTS tmp_target_CTL;
DROP TABLE IF EXISTS tmp_target_QS0;
DROP TABLE IF EXISTS tmp_target_QS;
DROP TABLE IF EXISTS tmp_gr;
DROP TABLE IF EXISTS tmp_gr_filtered;
DROP TABLE IF EXISTS tmp_gr_filtered1;
DROP TABLE IF EXISTS tmp_gr_qs;
DROP TABLE IF EXISTS tmp_root_qs;


v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;


















$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_target_all_obj_lg(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
	
	
	
	
    
    
    
    
    
    
    
    
    

/*
 * Change Log
 * 2024-10-04 Create function
 * 2025-04-14 Devide recursive by sources
 * */

DECLARE
v_tgt_schema_name TEXT DEFAULT 's_grnplm_ld_cib_gm_dsc_dcp_dv';
v_tgt_table_name TEXT DEFAULT 'meta_search_graph_target_all_obj';
v_params text DEFAULT '';
v_res_statements TEXT DEFAULT '';
v_proc_name text DEFAULT 'dg_full.return_meta_search_graph_target_all_obj';
v_interval_fr  timestamp;
v_deleted_row  int8;
v_inserted_row int8;
v_cnt          int8;
rec            record;
row_cn        INTEGER := 1; -- Переменная для подсчета прохода циклов

BEGIN

v_params := FORMAT('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
v_tgt_schema_name,
v_tgt_table_name,
p_wf_load_id,
p_wf_id);

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_gr - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_gr AS 
         SELECT DISTINCT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd,
            g.src_schema_src_id::text || '||'::text || g.src_node_src_id::text AS src_node_id,
            g.target_schema_src_id::text || '||'::text || g.target_node_src_id::text AS target_node_id,
            g.src_cd 
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1
           AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
DISTRIBUTED BY (src_node_id, target_node_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_gr;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_gr - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

-- tmp_target_CTL
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_target_CTL - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_target_CTL AS
WITH RECURSIVE search_graph
(src_schema_src_id, src_node_src_id, src_node_type_cd ,
 target_schema_src_id, target_node_src_id, tgt_node_type_cd,
 depth, path, cycle, 
 root_schema_src_id, root_node_src_id, root_node_type_cd,
 src_node_id, target_node_id,
 src_cd
 ) AS (
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_node_id::TEXT, 
            g.target_node_id::TEXT,
            g.src_cd
         FROM tmp_gr g
         WHERE 1 = 1
          AND g.tgt_node_type_cd IN  ('Flow', 'Entity') --  'Table', 'View', 'Application'
----           AND g.target_schema_src_id::TEXT NOT LIKE '%_stg_%'
----           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta','s_grnplm_as_cib_gm_mart_dg','s_grnplm_as_cib_gm_dg')
---- !!               AND (g.target_schema_src_id, g.target_node_src_id, g.tgt_node_type_cd) NOT IN (SELECT s.src_schema_src_id, s.src_node_src_id, s.src_node_type_cd FROM tmp_gr s)
        UNION ALL
         SELECT 
            nxt.src_schema_src_id::text,
            nxt.src_node_src_id::text,
            nxt.src_node_type_cd,
            nxt.target_schema_src_id::text,
            nxt.target_node_src_id::text,
            nxt.tgt_node_type_cd ,
            prv.depth + 1 AS depth,
            prv.path || nxt.src_node_id::text,
            nxt.src_node_id::text = ANY (prv.path),
            prv.root_schema_src_id::text,
            prv.root_node_src_id::TEXT,
            prv.root_node_type_cd,
            prv.src_node_id::TEXT , 
            nxt.target_node_id::TEXT ,
            nxt.src_cd
         FROM search_graph prv
         JOIN tmp_gr nxt 
----           ON prv.src_node_id::text = nxt.target_node_id::text
           ON prv.src_schema_src_id  = nxt.target_schema_src_id  
          AND prv.src_node_src_id  = nxt.target_node_src_id 
          AND prv.src_node_type_cd = nxt.tgt_node_type_cd  
         WHERE 1 = 1 
           AND NOT prv.cycle
        )
   SELECT DISTINCT  
      h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd, 
      h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd ,
      h.depth, 
      h.root_schema_src_id, 
      h.root_node_src_id,
      h.root_node_type_cd,
      h.src_cd
   FROM search_graph h
   WHERE 1=1
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_target_CTL;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_target_CTL - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

-- tmp_target_GP
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_target_GP - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_target_GP AS
WITH RECURSIVE search_graph
(src_schema_src_id, src_node_src_id, src_node_type_cd ,
 target_schema_src_id, target_node_src_id, tgt_node_type_cd,
 depth, path, cycle, 
 root_schema_src_id, root_node_src_id, root_node_type_cd,
 src_node_id, target_node_id,
 src_cd
 ) AS (
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_node_id::TEXT, 
            g.target_node_id::TEXT,
            g.src_cd
         FROM tmp_gr g
         WHERE 1 = 1
          AND g.tgt_node_type_cd IN  ('Table', 'View', 'Function') 
----           AND g.target_schema_src_id::TEXT NOT LIKE '%_stg_%'
----           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta','s_grnplm_as_cib_gm_mart_dg','s_grnplm_as_cib_gm_dg')
---- !!               AND (g.target_schema_src_id, g.target_node_src_id, g.tgt_node_type_cd) NOT IN (SELECT s.src_schema_src_id, s.src_node_src_id, s.src_node_type_cd FROM tmp_gr s)
        UNION ALL
         SELECT 
            nxt.src_schema_src_id::text,
            nxt.src_node_src_id::text,
            nxt.src_node_type_cd,
            nxt.target_schema_src_id::text,
            nxt.target_node_src_id::text,
            nxt.tgt_node_type_cd ,
            prv.depth + 1 AS depth,
            prv.path || nxt.src_node_id::text,
            nxt.src_node_id::text = ANY (prv.path),
            prv.root_schema_src_id::text,
            prv.root_node_src_id::TEXT,
            prv.root_node_type_cd,
            prv.src_node_id::TEXT , 
            nxt.target_node_id::TEXT ,
            nxt.src_cd
         FROM search_graph prv
         JOIN tmp_gr nxt 
----           ON prv.src_node_id::text = nxt.target_node_id::text
           ON prv.src_schema_src_id  = nxt.target_schema_src_id  
          AND prv.src_node_src_id  = nxt.target_node_src_id 
          AND prv.src_node_type_cd = nxt.tgt_node_type_cd  
         WHERE 1 = 1 
           AND NOT prv.cycle
        )
   SELECT DISTINCT  
      h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd, 
      h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd ,
      h.depth, 
      h.root_schema_src_id, 
      h.root_node_src_id,
      h.root_node_type_cd,
      h.src_cd
   FROM search_graph h
   WHERE 1=1
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_target_GP;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_target_GP - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_gr_qs - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_gr_qs AS 
         SELECT DISTINCT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd,
            g.src_schema_src_id::text || '||'::text || g.src_node_src_id::text AS src_node_id,
            g.target_schema_src_id::text || '||'::text || g.target_node_src_id::text AS target_node_id,
            g.src_cd 
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1
           AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
DISTRIBUTED BY (target_schema_src_id  , target_node_src_id  ,tgt_node_type_cd)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_gr_qs;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_gr_qs - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_root_qs - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_root_qs  AS 
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_schema_src_id::text || '||'::text || g.src_node_src_id::text AS src_node_id,
            g.target_schema_src_id::text || '||'::text || g.target_node_src_id::text AS target_node_id,
            g.src_cd
          FROM dg_full.meta_edge_link g
          WHERE 1 = 1
           AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
           AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta'/*,'s_grnplm_as_cib_gm_dg','s_grnplm_as_cib_gm_mart_dg'*/)
           AND g.tgt_node_type_cd IN  ('Application QS', 'SMD', 'Navi' ) 
           AND (g.target_schema_src_id, g.target_node_src_id, g.tgt_node_type_cd) NOT IN (SELECT s.src_schema_src_id, s.src_node_src_id, s.src_node_type_cd FROM tmp_gr s)
DISTRIBUTED BY (src_schema_src_id, src_node_src_id, src_node_type_cd )
;          
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_root_qs;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_root_qs - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


-- tmp_target_QS0
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_target_QS0 - ';
SELECT clock_timestamp() INTO v_interval_fr;
-- Создаем временную таблицу для накопления данных
CREATE TEMPORARY TABLE tmp_target_QS0 AS
SELECT 
    g.src_schema_src_id::text,
    g.src_node_src_id::text,
    g.src_node_type_cd,
    g.target_schema_src_id::text,
    g.target_node_src_id::text,
    g.tgt_node_type_cd,
    1 AS depth,
    ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
    false AS cycle,
    g.target_schema_src_id::text AS root_schema_src_id,
    g.target_node_src_id::text AS root_node_src_id,
    g.tgt_node_type_cd AS root_node_type_cd,
    g.src_node_id::TEXT,
    g.target_node_id::TEXT,
    g.src_cd
FROM tmp_root_qs g
DISTRIBUTED BY (src_schema_src_id, src_node_src_id,src_node_type_cd )
;

-- Выполняем цикл для обхода графа
row_cn := 1; -- Переменная для подсчета проходов цикла
BEGIN
    -- WHILE v_cnt > 0 LOOP
      WHILE row_cn < 12 LOOP
        -- Добавляем новый уровень вершин
        WITH new_nodes AS (
            SELECT 
                nxt.src_schema_src_id::text,
                nxt.src_node_src_id::text,
                nxt.src_node_type_cd,
                nxt.target_schema_src_id::text,
                nxt.target_node_src_id::text,
                nxt.tgt_node_type_cd,
                prv.depth + 1 AS depth,
                prv.path || nxt.src_node_id::TEXT AS path,
                nxt.src_node_id::text = ANY(prv.path) AS cycle,
                prv.root_schema_src_id::text,
                prv.root_node_src_id::TEXT,
                prv.root_node_type_cd,
                prv.src_node_id::TEXT,
                nxt.target_node_id::TEXT,
                nxt.src_cd
            FROM tmp_target_QS0 prv
            JOIN tmp_gr_qs nxt
              ON prv.src_schema_src_id = nxt.target_schema_src_id
             AND prv.src_node_src_id = nxt.target_node_src_id
             AND prv.src_node_type_cd = nxt.tgt_node_type_cd
             --LEFT JOIN tmp_gr_qs excl 
             -- ON prv.target_schema_src_id = excl.target_schema_src_id
             --AND prv.target_node_src_id = excl.target_node_src_id
             --AND prv.tgt_node_type_cd = excl.tgt_node_type_cd
            WHERE 1=1 
              AND NOT prv.CYCLE
              --AND excl.target_schema_src_id IS NULL 
        )
        INSERT INTO tmp_target_QS0
        SELECT * FROM new_nodes;
        
        -- Проверяем, сколько строк добавилось
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        row_cn := row_cn + 1; -- !!
        RAISE NOTICE 'tmp_target_QS0 - %, %:',row_cn, v_cnt;
    END LOOP;
END ;
RAISE NOTICE 'tmp_target_QS0';

-- Извлекаем результат из временной таблицы
CREATE TEMPORARY TABLE tmp_target_QS AS
SELECT 
    h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd,
    h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd,
    h.depth,
    h.root_schema_src_id,
    h.root_node_src_id,
    h.root_node_type_cd,
    h.src_cd
FROM tmp_target_QS0 h
DISTRIBUTED BY (src_schema_src_id, src_node_src_id,src_node_type_cd )
;


/*CREATE TEMPORARY TABLE tmp_target_QS AS
WITH RECURSIVE search_graph
(src_schema_src_id, src_node_src_id, src_node_type_cd ,
 target_schema_src_id, target_node_src_id, tgt_node_type_cd,
 depth, path, cycle, 
 root_schema_src_id, root_node_src_id, root_node_type_cd,
 src_node_id, target_node_id,
 src_cd
 ) AS (
         SELECT 
            g.src_schema_src_id::text,
            g.src_node_src_id::text,
            g.src_node_type_cd ,
            g.target_schema_src_id::text,
            g.target_node_src_id::text,
            g.tgt_node_type_cd ,
            1 AS depth,
            ARRAY[g.target_node_id::text, g.src_node_id::text] AS path,
            false AS cycle,
            g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text   AS root_node_src_id,
            g.tgt_node_type_cd           AS root_node_type_cd,
            g.src_node_id::TEXT, 
            g.target_node_id::TEXT,
            g.src_cd
         FROM tmp_root_qs g
         WHERE 1 = 1
        UNION ALL
         SELECT 
            nxt.src_schema_src_id::text,
            nxt.src_node_src_id::text,
            nxt.src_node_type_cd,
            nxt.target_schema_src_id::text,
            nxt.target_node_src_id::text,
            nxt.tgt_node_type_cd ,
            prv.depth + 1 AS depth,
            prv.path || nxt.src_node_id::text,
            nxt.src_node_id::text = ANY (prv.path),
            prv.root_schema_src_id::text,
            prv.root_node_src_id::TEXT,
            prv.root_node_type_cd,
            prv.src_node_id::TEXT , 
            nxt.target_node_id::TEXT ,
            nxt.src_cd
         FROM search_graph prv
         JOIN tmp_gr_qs nxt 
----           ON prv.src_node_id::text = nxt.target_node_id::text
           ON prv.src_schema_src_id  = nxt.target_schema_src_id  
          AND prv.src_node_src_id  = nxt.target_node_src_id 
          AND prv.src_node_type_cd = nxt.tgt_node_type_cd  
         WHERE 1 = 1 
           AND NOT prv.cycle
        )
   SELECT --DISTINCT  
      h.src_schema_src_id, h.src_node_src_id, h.src_node_type_cd, 
      h.target_schema_src_id, h.target_node_src_id, h.tgt_node_type_cd ,
      h.depth, 
      h.root_schema_src_id, 
      h.root_node_src_id,
      h.root_node_type_cd,
      h.src_cd
   FROM search_graph h
   WHERE 1=1
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;*/


GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_target_QS;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_target_QS - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

---------------------------------------------
/* Собираем цепочки из 3х источников - CTL\GP\QS */
v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_search_graph - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_search_graph AS
SELECT *
FROM tmp_target_GP
UNION ALL
SELECT *
FROM tmp_target_CTL 
UNION ALL
SELECT *
FROM tmp_target_QS
DISTRIBUTED BY (src_schema_src_id, src_node_src_id)
;
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_search_graph;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_search_graph - %, % ', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;


v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: */' || chr(10) || 'tmp_meta_search_graph_target_all_obj - ';
SELECT clock_timestamp() INTO v_interval_fr;
CREATE TEMPORARY TABLE tmp_meta_search_graph_target_all_obj AS 
WITH 
tmp_sql_2 AS ( /* SRC и TGT в один атрибут */
         SELECT 
--            replace(replace(replace(tmp_sql.src_node_id, '://'::text, '||'::text), '/'::text, '||'::text), ' '::text, '||'::text) AS node_id,
            tmp_sql.src_schema_src_id || '||' || tmp_sql.src_node_src_id   AS node_id,
            tmp_sql.src_schema_src_id::TEXT AS schema_src_id,
            tmp_sql.src_node_src_id::TEXT AS node_src_id,
            tmp_sql.src_node_type_cd AS node_type_cd,
            tmp_sql.depth,
            tmp_sql.root_schema_src_id || '||' || tmp_sql.root_node_src_id   AS root_node_id,
            tmp_sql.root_schema_src_id::TEXT,
            tmp_sql.root_node_src_id::TEXT,
            tmp_sql.root_node_type_cd,
            tmp_sql.src_cd
           FROM tmp_search_graph tmp_sql
        UNION ALL
         SELECT 
--            replace(replace(replace(tmp_sql.target_node_id, '://'::text, '||'::text), '/'::text, '||'::text), ' '::text, '||'::text) AS node_id,
            tmp_sql.target_schema_src_id || '||' || tmp_sql.target_node_src_id   AS node_id,
            tmp_sql.target_schema_src_id::TEXT AS schema_src_id,
            tmp_sql.target_node_src_id::TEXT AS node_src_id,
            tmp_sql.tgt_node_type_cd AS node_type_cd,
            tmp_sql.depth,
            tmp_sql.root_schema_src_id || '||' || tmp_sql.root_node_src_id   AS root_node_id,
            tmp_sql.root_schema_src_id::TEXT,
            tmp_sql.root_node_src_id::TEXT,
            tmp_sql.root_node_type_cd,
            tmp_sql.src_cd
           FROM tmp_search_graph tmp_sql
        )
 SELECT 
    tmp_sql_2.node_id::TEXT,
    tmp_sql_2.schema_src_id::text,
    tmp_sql_2.node_src_id::TEXT ,
    tmp_sql_2.node_type_cd::varchar(20),
    tmp_sql_2.src_cd::TEXT,
    min(tmp_sql_2.depth)::int4 AS depth,
    tmp_sql_2.root_node_id::TEXT,
    tmp_sql_2.root_schema_src_id::TEXT ,
    tmp_sql_2.root_node_src_id::TEXT ,
    tmp_sql_2.root_node_type_cd::varchar(20)
   FROM tmp_sql_2
  WHERE 1 = 1 AND tmp_sql_2.node_id !~~ '%_meta.%'::text
  GROUP BY 
           tmp_sql_2.node_id, 
           tmp_sql_2.schema_src_id,
           tmp_sql_2.node_src_id,
           tmp_sql_2.node_type_cd,
           tmp_sql_2.src_cd,
           tmp_sql_2.root_node_id, 
           tmp_sql_2.root_schema_src_id,
           tmp_sql_2.root_node_src_id,
           tmp_sql_2.root_node_type_cd
DISTRIBUTED BY (schema_src_id, node_src_id);
  
GET DIAGNOSTICS v_cnt = row_count;
ANALYZE tmp_meta_search_graph_target_all_obj;
v_res_statements := v_res_statements || age(clock_timestamp(), v_interval_fr)::text;
RAISE NOTICE 'tmp_meta_search_graph_target_all_obj - %, %', v_cnt, age(clock_timestamp() , v_interval_fr)::TEXT;

/*Очистка*/
v_res_statements := v_res_statements || chr(10) || '/* Delete: */'|| chr(10) || 'meta_search_graph_target_all_obj';
SELECT clock_timestamp() INTO v_interval_fr;
TRUNCATE TABLE dg_full.meta_search_graph_target_all_obj;
GET DIAGNOSTICS v_deleted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Delete Daily: */'|| chr(10) || 'meta_search_graph_target_all_obj'|| chr(9) || v_deleted_row::text;

/*Добавление новых данных*/
v_res_statements := v_res_statements || chr(10) || '/* Insert: */'|| chr(10) || 'meta_search_graph_target_all_obj ';
SELECT clock_timestamp() INTO v_interval_fr;
INSERT INTO dg_full.meta_search_graph_target_all_obj 
(   
    node_id ,
    schema_src_id ,
    node_src_id ,
    node_type_cd ,
    src_cd ,
    "depth" ,
    root_node_id ,
    root_schema_src_id ,
    root_node_src_id ,
    root_node_type_cd ,
    load_dttm ,
    wf_load_id ,
    eff_from_dttm ,
    eff_to_dttm ,
    last_seen_dttm ,
    root_is_active,
    is_active
)
SELECT  
    t.node_id,
    t.schema_src_id ,
    t.node_src_id ,
    t.node_type_cd,
    t.src_cd,
    t.depth,
    t.root_node_id,
    t.root_schema_src_id ,
    t.root_node_src_id ,
    t.root_node_type_cd ,
    now() AS load_dttm,
    - 1 AS wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    n.is_active AS root_is_active,
    n1.is_active AS is_active
FROM tmp_meta_search_graph_target_all_obj t
LEFT JOIN dg_full.meta_node_ref_table n ON t.root_schema_src_id = n.schema_src_id AND t.root_node_id = n.node_src_id 
LEFT JOIN dg_full.meta_node_ref_table n1 ON t.schema_src_id = n1.schema_src_id AND t.node_src_id = n1.node_src_id
;

GET DIAGNOSTICS v_inserted_row = row_count;
v_res_statements := v_res_statements || chr(10) || '/* Insert Daily: */'|| chr(10) || 'meta_search_graph_target_all_obj' || chr(9) || v_inserted_row::text;

RAISE NOTICE 'meta_search_graph_target_all_obj - %, %', v_inserted_row, age(clock_timestamp() , v_interval_fr)::text;

DROP TABLE IF EXISTS tmp_meta_search_graph_target_all_obj;
DROP TABLE IF EXISTS tmp_search_graph;
DROP TABLE IF EXISTS tmp_target_GP;
DROP TABLE IF EXISTS tmp_target_CTL;
DROP TABLE IF EXISTS tmp_target_QS0;
DROP TABLE IF EXISTS tmp_target_QS;
DROP TABLE IF EXISTS tmp_gr;
DROP TABLE IF EXISTS tmp_gr_qs;
DROP TABLE IF EXISTS tmp_root_qs;


v_res_statements := v_res_statements || chr(10) || '/* insert row count: */'|| chr(10) || v_inserted_row::varchar(10);
v_res_statements := v_res_statements || age(clock_timestamp() , v_interval_fr)::text;
PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name , p_wf_load_id, p_wf_id);
RETURN v_inserted_row;

EXCEPTION
       WHEN OTHERS THEN
            PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements||'::'||SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
            RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;










$$
EXECUTE ON ANY;

CREATE OR REPLACE FUNCTION dg_full.return_meta_search_graph_target_all_obj_opti(p_wf_load_id int8, p_wf_id int8)
	RETURNS int8
	LANGUAGE plpgsql
	VOLATILE
AS $$
	
/*
* Change Log
* 2024-10-04 Create function
* 2025-04-14 Devide recursive by sources
* 2025-04-30 Optimized: iterative BFS, single edge scan, improved temp tables
*/
DECLARE
    v_tgt_schema_name TEXT   := 's_grnplm_ld_cib_gm_dsc_dcp_dv';
    v_tgt_table_name  TEXT   := 'meta_search_graph_target_all_obj';
    v_params          TEXT   := '';
    v_res_statements  TEXT   := '';
    v_proc_name       TEXT   := 'dg_full.return_meta_search_graph_target_all_obj_opti';
    v_interval_fr     TIMESTAMP;
    v_deleted_row     INT8;
    v_inserted_row    INT8;
    v_cnt             INT8;
    v_depth_limit     INT    := 20;     -- для CTL и GP
    v_qs_depth_limit  INT    := 7;      -- для QS
    rec               RECORD;
BEGIN
    v_params := format('v_tgt_schema_name = %I ; v_tgt_table_name = %I ; p_wf_load_id = %I ; p_wf_id = %I ;',
                       v_tgt_schema_name, v_tgt_table_name, p_wf_load_id, p_wf_id);

    ANALYZE dg_full.meta_edge_link;
    ANALYZE dg_full.meta_node_ref_table;
    ANALYZE dg_full.meta_scheduler_hsat;
    ANALYZE dg_full.meta_screen_link;
    ANALYZE dg_full.meta_search_graph_target_all_obj;
                   
    -- ========================================================================
    -- 1. Подготовка рёбер графа (однократное сканирование meta_edge_link)
    -- ========================================================================
    v_res_statements := v_res_statements || chr(10) || '/* Create temporary table: tmp_edges */';
    SELECT clock_timestamp() INTO v_interval_fr;

    CREATE TEMP TABLE tmp_edges AS
    SELECT DISTINCT
        src_schema_src_id::TEXT,
        src_node_src_id::TEXT,
        src_node_type_cd,
        target_schema_src_id::TEXT,
        target_node_src_id::TEXT,
        tgt_node_type_cd,
        src_cd,
        src_schema_src_id || '||' || src_node_src_id AS src_node_id,
        target_schema_src_id || '||' || target_node_src_id AS target_node_id
    FROM dg_full.meta_edge_link g
    WHERE 1=1
      AND g.src_schema_src_id::TEXT NOT LIKE '%_ld_%'
      AND g.src_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta')
      AND g.target_schema_src_id::TEXT NOT LIKE '%_ld_%'
      AND g.target_schema_src_id::TEXT NOT IN ('s_grnplm_as_cib_gm_meta')
    DISTRIBUTED BY (src_node_id, target_node_id);

    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    ANALYZE tmp_edges;
    v_res_statements := v_res_statements || format(' - rows: %s, time: %s', v_cnt, age(clock_timestamp(), v_interval_fr)::TEXT);
    RAISE NOTICE 'tmp_edges - %, %', v_cnt, age(clock_timestamp(), v_interval_fr)::TEXT;

    -- Индексы для ускорения соединений при BFS
    CREATE INDEX ON tmp_edges (target_schema_src_id, target_node_src_id, tgt_node_type_cd);
    CREATE INDEX ON tmp_edges (src_schema_src_id, src_node_src_id, src_node_type_cd);
    CREATE INDEX ON tmp_edges (src_node_id);
    CREATE INDEX ON tmp_edges (target_node_id);

    -- ========================================================================
    -- 2. Вспомогательная функция для итеративного BFS (избегаем рекурсивных CTE)
    -- ========================================================================
    -- (используем временные таблицы, общие для всех обходов)

    -- ------------------------------------------------------------------------
    -- 2.1 Обход для CTL (типы узлов: Flow, Entity, TFS)
    -- ------------------------------------------------------------------------
    v_res_statements := v_res_statements || chr(10) || '/* BFS for CTL (Flow, Entity, TFS) */';
    SELECT clock_timestamp() INTO v_interval_fr;

    -- Корни (начальные target узлы рёбер с подходящим tgt_node_type_cd)
    CREATE TEMP TABLE tmp_roots_ctl AS
    SELECT
        target_schema_src_id AS schema_src_id,
        target_node_src_id   AS node_src_id,
        tgt_node_type_cd     AS node_type_cd,
        target_node_id       AS node_id,
        src_cd,
        target_schema_src_id AS root_schema_src_id,
        target_node_src_id   AS root_node_src_id,
        tgt_node_type_cd     AS root_node_type_cd,
        target_node_id       AS root_node_id
    FROM tmp_edges
    WHERE tgt_node_type_cd IN ('Flow', 'Entity', 'TFS')
    DISTRIBUTED BY (schema_src_id, node_src_id);

    -- Таблица для накопления всех путей (root, node, depth, src_cd)
    CREATE TEMP TABLE tmp_all_paths_ctl (
        root_schema_src_id TEXT,
        root_node_src_id   TEXT,
        root_node_type_cd  TEXT,
        root_node_id       TEXT,
        schema_src_id      TEXT,
        node_src_id        TEXT,
        node_type_cd       TEXT,
        node_id            TEXT,
        src_cd             TEXT,
        depth              INT
    ) DISTRIBUTED BY (root_node_id, node_id);

    -- Вставляем корни (глубина 1)
    INSERT INTO tmp_all_paths_ctl
    SELECT
        root_schema_src_id, root_node_src_id, root_node_type_cd, root_node_id,
        schema_src_id, node_src_id, node_type_cd, node_id,
        src_cd, 1
    FROM tmp_roots_ctl;

    -- Итеративное расширение (BFS) до глубины v_depth_limit
    FOR i IN 2..v_depth_limit LOOP
        -- Находим новые вершины, достижимые с предыдущего уровня
        CREATE TEMP TABLE tmp_new_level_ctl AS
        SELECT DISTINCT
            prv.root_schema_src_id,
            prv.root_node_src_id,
            prv.root_node_type_cd,
            prv.root_node_id,
            nxt.src_schema_src_id   AS schema_src_id,
            nxt.src_node_src_id     AS node_src_id,
            nxt.src_node_type_cd    AS node_type_cd,
            nxt.src_node_id         AS node_id,
            nxt.src_cd,
            i AS depth
        FROM tmp_all_paths_ctl prv
        JOIN tmp_edges nxt ON prv.schema_src_id = nxt.target_schema_src_id
                          AND prv.node_src_id   = nxt.target_node_src_id
                          AND prv.node_type_cd  = nxt.tgt_node_type_cd
        WHERE prv.depth = i-1
          AND NOT EXISTS (   -- избегаем циклов: узел уже есть в пути для данного корня
                SELECT 1 FROM tmp_all_paths_ctl existing
                WHERE existing.root_node_id = prv.root_node_id
                  AND existing.node_id = nxt.src_node_id
              );
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        EXIT WHEN v_cnt = 0;

        INSERT INTO tmp_all_paths_ctl
        SELECT * FROM tmp_new_level_ctl;

        DROP TABLE tmp_new_level_ctl;
    END LOOP;

    ANALYZE tmp_all_paths_ctl;
    v_res_statements := v_res_statements || format(' - rows: %s, time: %s',
        (SELECT COUNT(*) FROM tmp_all_paths_ctl), age(clock_timestamp(), v_interval_fr)::TEXT);
    RAISE NOTICE 'tmp_all_paths_ctl - %, %', (SELECT COUNT(*) FROM tmp_all_paths_ctl), age(clock_timestamp(), v_interval_fr)::TEXT;

    -- ------------------------------------------------------------------------
    -- 2.2 Обход для GP (типы узлов: Table, View, Function)
    -- ------------------------------------------------------------------------
    v_res_statements := v_res_statements || chr(10) || '/* BFS for GP (Table, View, Function) */';
    SELECT clock_timestamp() INTO v_interval_fr;

    CREATE TEMP TABLE tmp_roots_gp AS
    SELECT
        target_schema_src_id, target_node_src_id, tgt_node_type_cd, target_node_id,
        src_cd,
        target_schema_src_id AS root_schema_src_id,
        target_node_src_id   AS root_node_src_id,
        tgt_node_type_cd     AS root_node_type_cd,
        target_node_id       AS root_node_id
    FROM tmp_edges
    WHERE tgt_node_type_cd IN ('Table', 'View', 'Function')
    DISTRIBUTED BY (target_schema_src_id, target_node_src_id);

    CREATE TEMP TABLE tmp_all_paths_gp (
        root_schema_src_id TEXT,
        root_node_src_id   TEXT,
        root_node_type_cd  TEXT,
        root_node_id       TEXT,
        schema_src_id      TEXT,
        node_src_id        TEXT,
        node_type_cd       TEXT,
        node_id            TEXT,
        src_cd             TEXT,
        depth              INT
    ) DISTRIBUTED BY (root_node_id, node_id);

    INSERT INTO tmp_all_paths_gp
    SELECT
        root_schema_src_id, root_node_src_id, root_node_type_cd, root_node_id,
        target_schema_src_id, target_node_src_id, tgt_node_type_cd, target_node_id,
        src_cd, 1
    FROM tmp_roots_gp;

    FOR i IN 2..v_depth_limit LOOP
        CREATE TEMP TABLE tmp_new_level_gp AS
        SELECT DISTINCT
            prv.root_schema_src_id,
            prv.root_node_src_id,
            prv.root_node_type_cd,
            prv.root_node_id,
            nxt.src_schema_src_id,
           nxt.src_node_src_id,
            nxt.src_node_type_cd,
            nxt.src_node_id,
            nxt.src_cd,
            i
        FROM tmp_all_paths_gp prv
        JOIN tmp_edges nxt ON prv.schema_src_id = nxt.target_schema_src_id
                          AND prv.node_src_id   = nxt.target_node_src_id
                          AND prv.node_type_cd  = nxt.tgt_node_type_cd
        WHERE prv.depth = i-1
          AND NOT EXISTS (
                SELECT 1 FROM tmp_all_paths_gp existing
                WHERE existing.root_node_id = prv.root_node_id
                  AND existing.node_id = nxt.src_node_id
              );
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        EXIT WHEN v_cnt = 0;

        INSERT INTO tmp_all_paths_gp
        SELECT * FROM tmp_new_level_gp;
        DROP TABLE tmp_new_level_gp;
    END LOOP;

    ANALYZE tmp_all_paths_gp;
    v_res_statements := v_res_statements || format(' - rows: %s, time: %s',
        (SELECT COUNT(*) FROM tmp_all_paths_gp), age(clock_timestamp(), v_interval_fr)::TEXT);
    RAISE NOTICE 'tmp_all_paths_gp - %, %', (SELECT COUNT(*) FROM tmp_all_paths_gp), age(clock_timestamp(), v_interval_fr)::TEXT;

    -- ------------------------------------------------------------------------
    -- 2.3 Обход для QS (типы: Dashboard QS, Application QS, SMD, Application Navi)
    --     Глубина ограничена 7, корни – рёбра, у которых target НЕ встречается как source в tmp_edges
    -- ------------------------------------------------------------------------
    v_res_statements := v_res_statements || chr(10) || '/* BFS for QS (Dashboard QS, Application QS, SMD, Application Navi) */';
    SELECT clock_timestamp() INTO v_interval_fr;

    -- Корни для QS: все подходящие рёбра, чей target отсутствует в качестве source в общем графе
    CREATE TEMP TABLE tmp_roots_qs AS
    SELECT
        target_schema_src_id, target_node_src_id, tgt_node_type_cd, target_node_id,
        src_cd,
        target_schema_src_id AS root_schema_src_id,
        target_node_src_id   AS root_node_src_id,
        tgt_node_type_cd     AS root_node_type_cd,
        target_node_id       AS root_node_id
    FROM tmp_edges e
    WHERE e.tgt_node_type_cd IN ('Dashboard QS', 'Application QS', 'SMD', 'Application Navi')
      AND NOT EXISTS (
          SELECT 1 FROM tmp_edges s
          WHERE s.src_schema_src_id = e.target_schema_src_id
            AND s.src_node_src_id   = e.target_node_src_id
            AND s.src_node_type_cd  = e.tgt_node_type_cd
      )
    DISTRIBUTED BY (target_schema_src_id, target_node_src_id);

    CREATE TEMP TABLE tmp_all_paths_qs (
        root_schema_src_id TEXT,
        root_node_src_id   TEXT,
        root_node_type_cd  TEXT,
        root_node_id       TEXT,
        schema_src_id      TEXT,
        node_src_id        TEXT,
        node_type_cd       TEXT,
        node_id            TEXT,
        src_cd             TEXT,
        depth              INT
    ) DISTRIBUTED BY (root_node_id, node_id);

    INSERT INTO tmp_all_paths_qs
    SELECT
        root_schema_src_id, root_node_src_id, root_node_type_cd, root_node_id,
        target_schema_src_id, target_node_src_id, tgt_node_type_cd, target_node_id,
        src_cd, 1
    FROM tmp_roots_qs;

    FOR i IN 2..v_qs_depth_limit LOOP
        CREATE TEMP TABLE tmp_new_level_qs AS
        SELECT DISTINCT
            prv.root_schema_src_id,
            prv.root_node_src_id,
            prv.root_node_type_cd,
            prv.root_node_id,
            nxt.src_schema_src_id,
            nxt.src_node_src_id,
            nxt.src_node_type_cd,
            nxt.src_node_id,
            nxt.src_cd,
            i
        FROM tmp_all_paths_qs prv
        JOIN tmp_edges nxt ON prv.schema_src_id = nxt.target_schema_src_id
                          AND prv.node_src_id   = nxt.target_node_src_id
                          AND prv.node_type_cd  = nxt.tgt_node_type_cd
        WHERE prv.depth = i-1
          AND NOT EXISTS (
                SELECT 1 FROM tmp_all_paths_qs existing
                WHERE existing.root_node_id = prv.root_node_id
                  AND existing.node_id = nxt.src_node_id
              );
        GET DIAGNOSTICS v_cnt = ROW_COUNT;
        EXIT WHEN v_cnt = 0;

        INSERT INTO tmp_all_paths_qs
        SELECT * FROM tmp_new_level_qs;
        DROP TABLE tmp_new_level_qs;
    END LOOP;

    ANALYZE tmp_all_paths_qs;
    v_res_statements := v_res_statements || format(' - rows: %s, time: %s',
        (SELECT COUNT(*) FROM tmp_all_paths_qs), age(clock_timestamp(), v_interval_fr)::TEXT);
    RAISE NOTICE 'tmp_all_paths_qs - %, %', (SELECT COUNT(*) FROM tmp_all_paths_qs), age(clock_timestamp(), v_interval_fr)::TEXT;

    -- ========================================================================
    -- 3. Объединение результатов всех трёх обходов и формирование итоговых записей
    -- ========================================================================
    v_res_statements := v_res_statements || chr(10) || '/* Combine and build final result */';
    SELECT clock_timestamp() INTO v_interval_fr;

    CREATE TEMP TABLE tmp_combined AS
    SELECT
        schema_src_id,
        node_src_id,
        node_type_cd,
        src_cd,
        depth,
        root_schema_src_id,
        root_node_src_id,
        root_node_type_cd,
        root_node_id
    FROM tmp_all_paths_ctl
    UNION ALL
    SELECT
        schema_src_id, node_src_id, node_type_cd, src_cd, depth,
        root_schema_src_id, root_node_src_id, root_node_type_cd, root_node_id
    FROM tmp_all_paths_gp
    UNION ALL
    SELECT
        schema_src_id, node_src_id, node_type_cd, src_cd, depth,
        root_schema_src_id, root_node_src_id, root_node_type_cd, root_node_id
    FROM tmp_all_paths_qs
    DISTRIBUTED BY (schema_src_id, node_src_id);

    ANALYZE tmp_combined;

    -- Разворачиваем source и target в единый список узлов, оставляем минимальную глубину
    CREATE TEMP TABLE tmp_final_nodes AS
    SELECT
        node_id,
        schema_src_id,
        node_src_id,
        node_type_cd,
        src_cd,
        MIN(depth) AS depth,
        root_node_id,
        root_schema_src_id,
        root_node_src_id,
        root_node_type_cd
    FROM (
        -- узел как source
        SELECT
            schema_src_id || '||' || node_src_id AS node_id,
            schema_src_id,
            node_src_id,
            node_type_cd,
            src_cd,
            depth,
            root_node_id,
            root_schema_src_id,
            root_node_src_id,
            root_node_type_cd
        FROM tmp_combined
        UNION ALL
        -- узел как target (source того же ребра, но уже представлен, а target — это корень; по логике исходной функции узел может быть и target’ом)
        SELECT
            root_node_id,
            root_schema_src_id,
            root_node_src_id,
            root_node_type_cd,
            src_cd,
            depth,
            root_node_id,
            root_schema_src_id,
            root_node_src_id,
            root_node_type_cd
        FROM tmp_combined
    ) all_nodes
    WHERE node_id NOT LIKE '%_meta.%'  -- исключаем служебные мета-схемы
    GROUP BY node_id, schema_src_id, node_src_id, node_type_cd, src_cd,
             root_node_id, root_schema_src_id, root_node_src_id, root_node_type_cd
    DISTRIBUTED BY (schema_src_id, node_src_id);

    ANALYZE tmp_final_nodes;

    -- ========================================================================
    -- 4. Очистка целевой таблицы и вставка новых данных
    -- ========================================================================
    v_res_statements := v_res_statements || chr(10) || '/* Truncate target table */';
    SELECT clock_timestamp() INTO v_interval_fr;
    TRUNCATE TABLE dg_full.meta_search_graph_target_all_obj;
    GET DIAGNOSTICS v_deleted_row = ROW_COUNT;
    v_res_statements := v_res_statements || format(' - rows deleted: %s', v_deleted_row);

    v_res_statements := v_res_statements || chr(10) || '/* Insert into target table */';
    INSERT INTO dg_full.meta_search_graph_target_all_obj
    (
        node_id, schema_src_id, node_src_id, node_type_cd, src_cd, depth,
        root_node_id, root_schema_src_id, root_node_src_id, root_node_type_cd,
        load_dttm, wf_load_id, eff_from_dttm, eff_to_dttm, last_seen_dttm,
        root_is_active, is_active
    )
    SELECT DISTINCT
        f.node_id,
        f.schema_src_id,
        f.node_src_id,
        f.node_type_cd,
        f.src_cd,
        f.depth,
        f.root_node_id,
        f.root_schema_src_id,
        f.root_node_src_id,
        f.root_node_type_cd,
        now() AS load_dttm,
        -1    AS wf_load_id,
        '1900-01-01'::TIMESTAMP AS eff_from_dttm,
        '2999-12-31'::TIMESTAMP AS eff_to_dttm,
        now() AS last_seen_dttm,
        n.is_active AS root_is_active,
        n1.is_active AS is_active
    FROM tmp_final_nodes f
    LEFT JOIN dg_full.meta_node_ref_table n
        ON f.root_schema_src_id = n.schema_src_id AND f.root_node_src_id = n.node_src_id
    LEFT JOIN dg_full.meta_node_ref_table n1
        ON f.schema_src_id = n1.schema_src_id AND f.node_src_id = n1.node_src_id;

    GET DIAGNOSTICS v_inserted_row = ROW_COUNT;
    v_res_statements := v_res_statements || format(' - inserted rows: %s, time: %s', v_inserted_row, age(clock_timestamp(), v_interval_fr)::TEXT);
    RAISE NOTICE 'meta_search_graph_target_all_obj - inserted: %, time: %', v_inserted_row, age(clock_timestamp(), v_interval_fr)::TEXT;

    -- ========================================================================
    -- 5. Очистка временных таблиц
    -- ========================================================================
    DROP TABLE IF EXISTS tmp_edges;
    DROP TABLE IF EXISTS tmp_roots_ctl;
    DROP TABLE IF EXISTS tmp_all_paths_ctl;
    DROP TABLE IF EXISTS tmp_roots_gp;
    DROP TABLE IF EXISTS tmp_all_paths_gp;
    DROP TABLE IF EXISTS tmp_roots_qs;
    DROP TABLE IF EXISTS tmp_all_paths_qs;
    DROP TABLE IF EXISTS tmp_combined;
    DROP TABLE IF EXISTS tmp_final_nodes;
    DROP TABLE IF EXISTS tmp_new_level_ctl;

    -- Логирование (сохраняем прежнюю процедуру логирования)
    PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements, v_params, v_proc_name, p_wf_load_id, p_wf_id);
    RETURN v_inserted_row;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM s_grnplm_as_cib_gm_meta.save_step_to_logs(v_res_statements || '::' || SQLERRM, v_params, v_proc_name, p_wf_load_id, p_wf_id);
        RAISE EXCEPTION '(%:%:%)', v_params, v_res_statements, SQLERRM;
END;

$$
EXECUTE ON ANY;
