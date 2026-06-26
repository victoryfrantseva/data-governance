-- dg_full.meta_search_graph_flow source

CREATE OR REPLACE VIEW dg_full.meta_search_graph_flow
AS SELECT t1.node_id AS flow_node_id,
    t1.node_type_cd AS flow_node_type_cd,
    t1.src_cd AS flow_src_cd,
    t1.schema_src_id AS flow_schema_src_id,
    t1.node_src_id AS flow_node_src_id,
    t2.node_id,
    t2.node_type_cd,
    t2.src_cd,
    t2.depth,
    t2.schema_src_id,
    t2.node_src_id
   FROM dg_full.meta_search_graph_target_all_obj t1
     JOIN dg_full.meta_search_graph_target_all_obj t2 ON t1.root_node_id = t2.root_node_id
  WHERE 1 = 1 AND t1.node_type_cd::text = 'Flow'::text
  GROUP BY t1.node_id, t1.node_type_cd, t1.src_cd, t1.schema_src_id, t1.node_src_id, t2.node_id, t2.node_type_cd, t2.src_cd, t2.depth, t2.schema_src_id, t2.node_src_id;


-- dg_full.qs_meta_error_event_fact source

CREATE OR REPLACE VIEW dg_full.qs_meta_error_event_fact
AS SELECT meta_error_event_fact.batch_id,
    meta_error_event_fact.screen_id,
    meta_error_event_fact.schema_src_id,
    meta_error_event_fact.table_src_id,
    meta_error_event_fact.check_sql,
    meta_error_event_fact.final_severity_score,
    meta_error_event_fact.record_identifier,
    meta_error_event_fact.metric,
    meta_error_event_fact.key_metric,
    meta_error_event_fact.record_error,
    meta_error_event_fact.value,
    meta_error_event_fact.src_cd,
    date_trunc('day'::text, meta_error_event_fact.load_dttm) AS load_date,
    meta_error_event_fact.load_dttm AS "meta_error_event_fact.load_dttm"
   FROM dg_full.meta_error_event_fact
     JOIN dg_full.meta_batch_fact ON meta_error_event_fact.batch_id = meta_batch_fact.batch_id
  WHERE 1 = 1 AND meta_batch_fact.stts = 'OK'::text AND meta_error_event_fact.record_identifier::jsonb ?| ARRAY['unit'::text];


-- dg_full.qs_meta_error_event_fact_detail source

CREATE OR REPLACE VIEW dg_full.qs_meta_error_event_fact_detail
AS SELECT meta_error_event_fact.batch_id,
    meta_error_event_fact.screen_id,
    meta_error_event_fact.schema_src_id,
    meta_error_event_fact.table_src_id,
    meta_error_event_fact.check_sql,
    meta_error_event_fact.final_severity_score,
    meta_error_event_fact.record_identifier,
    meta_error_event_fact.metric,
    meta_error_event_fact.key_metric,
    meta_error_event_fact.record_error,
    meta_error_event_fact.value,
    meta_error_event_fact.src_cd,
    date_trunc('day'::text, meta_error_event_fact.load_dttm) AS load_date,
    meta_error_event_fact.load_dttm AS "meta_error_event_fact.load_dttm"
   FROM dg_full.meta_error_event_fact
     JOIN dg_full.meta_batch_fact ON meta_error_event_fact.batch_id = meta_batch_fact.batch_id
  WHERE 1 = 1 AND meta_batch_fact.stts = 'OK'::text AND NOT meta_error_event_fact.record_identifier::jsonb ?| ARRAY['unit'::text];


-- dg_full.qs_meta_error_hfact_tib_clients_detail source

CREATE OR REPLACE VIEW dg_full.qs_meta_error_hfact_tib_clients_detail
AS SELECT meta_error_event_fact.batch_id,
    meta_error_event_fact.screen_id,
    meta_error_event_fact.schema_src_id,
    meta_error_event_fact.table_src_id,
    meta_error_event_fact.check_sql,
    meta_error_event_fact.final_severity_score,
    meta_error_event_fact.record_identifier,
    meta_error_event_fact.metric,
    meta_error_event_fact.key_metric,
    meta_error_event_fact.record_error,
    meta_error_event_fact.value,
    meta_error_event_fact.src_cd,
    date_trunc('day'::text, meta_error_event_fact.load_dttm) AS load_date,
    meta_error_event_fact.load_dttm AS "meta_error_event_fact.load_dttm",
    meta_error_event_fact.record_identifier -> 'reporting_date'::text AS reporting_date,
    meta_error_event_fact.record_identifier -> 'crm_id'::text AS crm_id,
    meta_error_event_fact.record_identifier -> 'epk_id'::text AS epk_id,
    meta_error_event_fact.record_identifier -> 'report_id'::text AS report_id,
    meta_error_event_fact.record_identifier -> 'client_tib_id'::text AS client_tib_id
   FROM dg_full.meta_error_event_fact
     JOIN dg_full.meta_batch_fact ON meta_error_event_fact.batch_id = meta_batch_fact.batch_id
  WHERE 1 = 1 AND meta_batch_fact.stts = 'OK'::text AND NOT meta_error_event_fact.record_identifier::jsonb ?| ARRAY['unit'::text];


-- dg_full.qs_meta_error_hfact_tib_clients_diff source

CREATE OR REPLACE VIEW dg_full.qs_meta_error_hfact_tib_clients_diff
AS SELECT m.batch_id,
    m.screen_id,
    m.schema_src_id,
    m.table_src_id,
    m.metric,
    m.record_error,
    m.value,
    m.load_dttm,
    m.record_identifier ->> 'date_prev'::text AS date_prev,
    m.record_identifier ->> 'date_curr'::text AS date_curr,
    m.record_identifier ->> 'report_id'::text AS report_id,
    m.record_identifier ->> 'name'::text AS name,
    m.record_identifier ->> 'epk_id_prev'::text AS epk_id_prev,
    m.record_identifier ->> 'epk_id_curr'::text AS epk_id_curr,
    m.record_identifier ->> 'crm_segment_prev'::text AS crm_segment_prev,
    m.record_identifier ->> 'crm_segment_curr'::text AS crm_segment_curr,
    m.record_identifier ->> 'crm_segment_diff'::text AS crm_segment_diff,
    m.record_identifier ->> 'kc_flg_prev'::text AS kc_flg_prev,
    m.record_identifier ->> 'kc_flg_curr'::text AS kc_flg_curr,
    m.record_identifier ->> 'kc_flg_diff'::text AS kc_flg_diff,
    m.record_identifier ->> 'employeefullname_prev'::text AS employeefullname_prev,
    m.record_identifier ->> 'employeefullname_curr'::text AS employeefullname_curr,
    m.record_identifier ->> 'employeefullname_diff'::text AS employeefullname_diff,
    m.record_identifier ->> 'holding_id_parent_prev'::text AS holding_id_parent_prev,
    m.record_identifier ->> 'holding_id_parent_curr'::text AS holding_id_parent_curr,
    m.record_identifier ->> 'holding_id_parent_diff'::text AS holding_id_parent_diff,
    m.record_identifier ->> 'holding_name_parent_prev'::text AS holding_name_parent_prev,
    m.record_identifier ->> 'holding_name_parent_curr'::text AS holding_name_parent_curr,
    m.record_identifier ->> 'holding_name_parent_diff'::text AS holding_name_parent_diff,
    m.record_identifier ->> 'holding_id_head_prev'::text AS holding_id_head_prev,
    m.record_identifier ->> 'holding_id_head_curr'::text AS holding_id_head_curr,
    m.record_identifier ->> 'holding_id_head_diff'::text AS holding_id_head_diff,
    m.record_identifier ->> 'holding_name_head_prev'::text AS holding_name_head_prev,
    m.record_identifier ->> 'holding_name_head_curr'::text AS holding_name_head_curr,
    m.record_identifier ->> 'holding_name_head_diff'::text AS holding_name_head_diff,
    m.record_identifier ->> 'tb_name_prev'::text AS tb_name_prev,
    m.record_identifier ->> 'tb_name_curr'::text AS tb_name_curr,
    m.record_identifier ->> 'tb_name_diff'::text AS tb_name_diff,
    m.record_identifier ->> 'koo_name_prev'::text AS koo_name_prev,
    m.record_identifier ->> 'koo_name_curr'::text AS koo_name_curr,
    m.record_identifier ->> 'koo_name_diff'::text AS koo_name_diff,
    m.record_identifier ->> 'kko_name_prev'::text AS kko_name_prev,
    m.record_identifier ->> 'kko_name_curr'::text AS kko_name_curr,
    m.record_identifier ->> 'kko_name_diff'::text AS kko_name_diff,
    m.record_identifier ->> 'crh_tabnumber_prev'::text AS crh_tabnumber_prev,
    m.record_identifier ->> 'crh_tabnumber_curr'::text AS crh_tabnumber_curr,
    m.record_identifier ->> 'crh_tabnumber_diff'::text AS crh_tabnumber_diff,
    m.record_identifier ->> 'crh_fio_prev'::text AS crh_fio_prev,
    m.record_identifier ->> 'crh_fio_curr'::text AS crh_fio_curr,
    m.record_identifier ->> 'crh_fio_diff'::text AS crh_fio_diff,
    m.record_identifier ->> 'crh_flg_prev'::text AS crh_flg_prev,
    m.record_identifier ->> 'crh_flg_curr'::text AS crh_flg_curr,
    m.record_identifier ->> 'crh_flg_diff'::text AS crh_flg_diff,
    m.record_identifier ->> 'kc_flg'::text AS kc_flg
   FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact m
     JOIN s_grnplm_as_cib_gm_dg.meta_batch_fact b ON m.batch_id = b.batch_id
  WHERE 1 = 1 AND m.screen_id = 1404 AND NOT m.record_identifier::jsonb ?| ARRAY['unit'::text];


-- dg_full.qs_meta_object_ref_table source

CREATE OR REPLACE VIEW dg_full.qs_meta_object_ref_table
AS SELECT meta_screen_link.screen_id,
    meta_screen_link.object_group_id,
    meta_object_ref_table.load_dttm AS "meta_object_ref_table.load_dttm",
    meta_object_ref_table.schema_src_id,
    meta_object_ref_table.table_src_id,
    meta_object_ref_table.attribute_src_id,
    meta_object_ref_table.object_order
   FROM dg_full.meta_screen_link
     JOIN dg_full.meta_object_ref_table ON meta_object_ref_table.object_group_id = meta_screen_link.object_group_id
  GROUP BY meta_screen_link.screen_id, meta_screen_link.object_group_id, meta_object_ref_table.load_dttm, meta_object_ref_table.schema_src_id, meta_object_ref_table.table_src_id, meta_object_ref_table.attribute_src_id, meta_object_ref_table.object_order;


-- dg_full.qs_meta_screen_link source

CREATE OR REPLACE VIEW dg_full.qs_meta_screen_link
AS SELECT meta_screen_link.screen_id,
    meta_screen_link.screen_template_id,
    meta_screen_link.object_group_id,
    meta_screen_link.load_dttm AS "meta_screen_link.load_dttm",
    meta_screen_template_ref_table.screen_category,
    meta_screen_template_ref_table.descr,
    meta_object_group_ref_table.object_group_name
   FROM dg_full.meta_screen_link
     JOIN dg_full.meta_screen_template_ref_table ON meta_screen_link.screen_template_id = meta_screen_template_ref_table.screen_template_id
     JOIN dg_full.meta_object_group_ref_table ON meta_screen_link.object_group_id = meta_object_group_ref_table.object_group_id
     JOIN dg_full.meta_object_ref_table ON meta_object_ref_table.object_group_id = meta_object_group_ref_table.object_group_id
  GROUP BY meta_screen_link.screen_id, meta_screen_link.screen_template_id, meta_screen_link.object_group_id, meta_screen_link.load_dttm, meta_screen_template_ref_table.screen_category, meta_screen_template_ref_table.descr, meta_object_group_ref_table.object_group_name;


-- dg_full.vctl_category source

CREATE OR REPLACE VIEW dg_full.vctl_category
AS SELECT c1.deleted,
    c1.id,
    c1.name AS name_,
    c1.parentid AS parent_id
   FROM s_grnplm_as_cib_gm_ods_ctl.category c1
  WHERE 1 = 1 AND c1.eff_to_dttm::date = '2999-12-31'::date;


-- dg_full.vctl_export source

CREATE OR REPLACE VIEW dg_full.vctl_export
AS SELECT json_build_object('wf_name', w.name_, 'category', w.category_nm, 'scheduled', w.scheduled, 'deleted', w.deleted, 'scenario', p.rin, 'id', w.id, 'profile', w.profile_nm, 'entity', json_agg(p.tgt_entity_id), 'src_table', COALESCE(p.src_espd_table_name, p.src_hdp_table_name, p.src_hdp_snp_table_name, p.src_hdp_diff_table_name), 'tgt_table', p.tgt_table_name, 'src_schema', COALESCE(p.src_espd_schema_name, p.src_hdp_schema_name, p.src_hdp_snp_schema_name, p.src_hdp_diff_schema_name), 'tgt_schema', p.tgt_schema_name, 'wf_time_sched', w.wf_time_sched_sched, 'cron_schedule', w.wf_time_sched_active, 'wf_event_sched', json_agg(w1.entity_id)) AS wf_list
   FROM dg_full.vctl_wf w
     JOIN dg_full.vctl_wf_event_sched w1 ON w.id::text = w1.wf_id
     JOIN dg_full.vctl_wf_params p ON w.id = p.wf_id
  GROUP BY w.name_, w.category_nm, w.scheduled, w.deleted, p.rin, w.id, w.profile_nm, COALESCE(p.src_espd_table_name, p.src_hdp_table_name, p.src_hdp_snp_table_name, p.src_hdp_diff_table_name), p.tgt_table_name, COALESCE(p.src_espd_schema_name, p.src_hdp_schema_name, p.src_hdp_snp_schema_name, p.src_hdp_diff_schema_name), p.tgt_schema_name, w.wf_time_sched_sched, w.wf_time_sched_active;


-- dg_full.vctl_init_lock_check source

CREATE OR REPLACE VIEW dg_full.vctl_init_lock_check
AS SELECT w1.id AS wf_id,
    params.entity_id,
    w1.eff_from_dttm AS updated_dttm,
    params.lock,
    params.lock_group,
    w1.eff_from_dttm AS created_dttm,
    p1.id AS profile_id,
    params.profile AS profile_nm
   FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
     JOIN LATERAL json_populate_recordset(NULL::record, w1.init_lock_check::json) params(lock text, profile text, lock_group text, entity_id text, wf_id text) ON true
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON w1.profile = p1.name_::text
  WHERE 1 = 1 AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
          WHERE w2.id = w1.id));


-- dg_full.vctl_init_lock_set source

CREATE OR REPLACE VIEW dg_full.vctl_init_lock_set
AS SELECT w1.eff_from_dttm AS created_dttm,
    params.estimate,
    params.lock,
    params.lock_group,
    p1.id AS profile_id,
    params.profile AS profile_nm,
    w1.eff_from_dttm AS updated_dttm,
    params.entity_id,
    w1.id AS wf_id
   FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
     JOIN LATERAL json_populate_recordset(NULL::record, w1.init_lock_set::json) params(estimate text, lock text, profile text, lock_group text, entity_id text, wf_id text) ON true
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON w1.profile = p1.name_::text
  WHERE 1 = 1 AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
          WHERE w2.id = w1.id));


-- dg_full.vctl_loading source

CREATE OR REPLACE VIEW dg_full.vctl_loading
AS SELECT NULL::boolean AS abort_on_failure,
    NULL::text AS active_trigger_id,
    pv1.alive,
    NULL::integer AS attempts_left,
    pv1.auto,
    pv1.eff_from_dttm AS created_dttm,
    NULL::boolean AS deschedule_on_failure,
    pv1.end_dttm,
    pv1.start_dttm AS expected_start_dttm,
    pv1.id,
    p1.id AS profile_id,
    pv1.profile AS profile_nm,
    NULL::integer AS retry_delay_ms,
    pv1.start_dttm,
    pv1.status,
    pv1.status_log,
    pv1.eff_from_dttm AS updated_dttm,
    pv1.wf_id,
    pv1.xid
   FROM s_grnplm_as_cib_gm_ods_ctl.loading pv1
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON pv1.profile = p1.name_::text
  WHERE 1 = 1 AND pv1.eff_to_dttm::date = '2999-12-31'::date;


-- dg_full.vctl_loading_status source

CREATE OR REPLACE VIEW dg_full.vctl_loading_status
AS WITH tt_spr AS (
         SELECT tt.stts_id,
            tt.stts_nm
           FROM ( VALUES (1,'EVENT-WAIT'::text), (2,'TIME-WAIT'::text), (3,'PREREQ'::text), (4,'LOCK-WAIT'::text), (5,'PARAM'::text), (6,'START'::text), (7,'RUNNING'::text), (8,'SUCCESS'::text), (9,'ERROR'::text)) tt(stts_id, stts_nm)
        ), tt AS (
         SELECT params.effective_from::timestamp without time zone AS effective_from,
            pv1.id::bigint AS id,
            params.loading_id::bigint AS loading_id,
            pv1.status_log AS log,
            params.status,
            pv1.wf_id::bigint AS wf_id
           FROM s_grnplm_as_cib_gm_ods_ctl.loading pv1
             JOIN LATERAL json_populate_recordset(NULL::record, pv1.loading_status::json) params(effective_from text, loading_id text, status text) ON true
          WHERE 1 = 1 AND pv1.eff_to_dttm::date = '2999-12-31'::date
        ), tt1 AS (
         SELECT tt.effective_from,
            tt.id,
            tt.loading_id,
            tt.log,
            tt.status,
            tt.wf_id,
            lead(tt.effective_from) OVER (PARTITION BY tt.wf_id, tt.id ORDER BY tt.effective_from) AS effective_to
           FROM tt
          WHERE 1 = 1
        ), tt01 AS (
         SELECT tt1_1.loading_id,
            tt1_1.wf_id,
                CASE
                    WHEN tt1_1.effective_from = (max(tt1_1.effective_from) OVER (PARTITION BY tt1_1.loading_id, tt1_1.wf_id)) THEN tt1_1.status
                    ELSE NULL::text
                END AS stts_nm
           FROM tt1 tt1_1
          WHERE 1 = 1
        )
 SELECT tt1.id AS wf_loading_id,
    tt1.wf_id,
    tt1.log,
    max(
        CASE
            WHEN tt1.status = 'EVENT-WAIT'::text THEN tt1.effective_from
            ELSE NULL::timestamp without time zone
        END) AS stts_event_wait,
    max(
        CASE
            WHEN tt1.status = 'TIME-WAIT'::text THEN tt1.effective_from
            ELSE NULL::timestamp without time zone
        END) AS stts_time_wait,
    min(
        CASE
            WHEN tt1.status = ANY (ARRAY['PREREQ'::text, 'LOCK-WAIT'::text, 'PARAM'::text, 'START'::text, 'RUNNING'::text, 'SUCCESS'::text, 'ERROR'::text]) THEN tt1.effective_from
            ELSE NULL::timestamp without time zone
        END) AS start_dttm,
    max(
        CASE
            WHEN tt1.status = ANY (ARRAY['PREREQ'::text, 'LOCK-WAIT'::text, 'PARAM'::text, 'START'::text, 'RUNNING'::text, 'SUCCESS'::text, 'ERROR'::text]) THEN tt1.effective_from
            ELSE NULL::timestamp without time zone
        END) AS end_dttm,
    tt01.stts_nm
   FROM tt1
     LEFT JOIN tt01 ON tt1.loading_id = tt01.loading_id AND tt1.wf_id = tt01.wf_id AND tt01.stts_nm IS NOT NULL
  WHERE 1 = 1
  GROUP BY tt1.id, tt1.log, tt1.wf_id, tt01.stts_nm;


-- dg_full.vctl_param source

CREATE OR REPLACE VIEW dg_full.vctl_param
AS WITH tt AS (
         SELECT NULL::text AS action,
            NULL::text AS jclass,
            params.param,
            NULL::text AS parent_action,
            params.wf_id AS principal_wf_id,
            params.prior_value,
            p1.id AS profile_id,
            p1.name_ AS profile_nm,
            w1.id AS wf_id,
            row_number() OVER (PARTITION BY w1.id, params.param ORDER BY w1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
             JOIN LATERAL json_populate_recordset(NULL::record, w1.param::json) params(param text, prior_value text, wf_id text) ON true
             LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON w1.profile = p1.name_::text
          WHERE 1 = 1 AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
                   FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
                  WHERE w2.id = w1.id))
        )
 SELECT tt.action,
    tt.jclass,
    tt.param,
    tt.parent_action,
    tt.principal_wf_id,
    tt.prior_value,
    tt.profile_id,
    tt.profile_nm,
    tt.wf_id
   FROM tt
  WHERE tt.rn_ = 1;


-- dg_full.vctl_param_value source

CREATE OR REPLACE VIEW dg_full.vctl_param_value
AS WITH tt AS (
         SELECT pv1.id AS loading_id,
            params.param,
            NULL::text AS parent_action,
            params.wf_id AS principal_wf_id,
            params.value,
            pv1.wf_id,
            row_number() OVER (PARTITION BY pv1.wf_id, params.param ORDER BY pv1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.loading pv1
             JOIN LATERAL json_populate_recordset(NULL::record, pv1.params::json) params(loading_id text, param text, value text, wf_id text) ON true
          WHERE pv1.eff_to_dttm::date = '2999-12-31'::date
        )
 SELECT tt.loading_id,
    tt.param,
    tt.parent_action,
    tt.principal_wf_id,
    tt.value,
    tt.wf_id
   FROM tt
  WHERE tt.rn_ = 1;


-- dg_full.vctl_stat_value source

CREATE OR REPLACE VIEW dg_full.vctl_stat_value
AS WITH tt AS (
         SELECT params.entity_id,
            params.id,
            params.loading_id,
            params.profile_id,
            params.profile AS profile_nm,
            params.published_dttm,
            params.stat_id,
            params.value,
            pv1.wf_id,
            row_number() OVER (PARTITION BY pv1.wf_id, params.id ORDER BY pv1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.loading pv1
             JOIN LATERAL json_populate_recordset(NULL::record, pv1.stats::json) params(entity_id text, id text, loading_id text, profile text, profile_id text, published_dttm text, stat_id text, value text) ON true
             LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON pv1.profile = p1.name_::text
          WHERE 1 = 1 AND pv1.eff_to_dttm::date = '2999-12-31'::date AND pv1.stats IS NOT NULL
        )
 SELECT tt.entity_id,
    tt.id,
    tt.loading_id,
    tt.profile_id,
    tt.profile_nm,
    tt.published_dttm,
    tt.stat_id,
    tt.value,
    tt.wf_id
   FROM tt
  WHERE tt.rn_ = 1;


-- dg_full.vctl_status_notification source

CREATE OR REPLACE VIEW dg_full.vctl_status_notification
AS WITH tt AS (
         SELECT w1.eff_from_dttm AS created_dttm,
            w1.id,
            params.emails AS mail,
            params.status,
            w1.eff_from_dttm AS updated_dttm,
            w1.id AS wf_id,
            row_number() OVER (PARTITION BY w1.id, params.status ORDER BY w1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
             JOIN LATERAL json_populate_recordset(NULL::record, w1.statusnotifications::json) params(emails text, status text) ON true
          WHERE 1 = 1 AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
                   FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
                  WHERE w2.id = w1.id))
        )
 SELECT tt.created_dttm,
    tt.id,
    tt.mail,
    tt.status,
    tt.updated_dttm,
    tt.wf_id
   FROM tt
  WHERE tt.rn_ = 1;


-- dg_full.vctl_wf source

CREATE OR REPLACE VIEW dg_full.vctl_wf
AS SELECT tt.category_id,
    tt.category_nm,
    tt.created_dttm,
    tt.deleted,
    tt.engine,
    tt.event_await_strategy,
    tt.id,
    tt.id_text,
    tt.inf_app_name,
    tt.inf_folder,
    tt.inf_project,
    tt.inf_workflow,
    tt.kill_yarn_job_on_error,
    tt.name_,
    tt.profile_id,
    tt.profile_nm,
    tt.scheduled,
    tt.single_loading,
    tt.start_condition,
    tt.type,
    tt.wf_time_sched_active,
    tt.wf_time_sched_faulttolerance,
    tt.wf_time_sched_sched,
    tt.wf_time_sched_wf_id,
    tt.updated_dttm,
    tt.rn_
   FROM ( SELECT c1.id AS category_id,
            w1.category AS category_nm,
            w1.eff_from_dttm AS created_dttm,
            w1.deleted,
            w1.engine,
            w1.eventawaitstrategy AS event_await_strategy,
            w1.id,
            w1.id::text AS id_text,
            NULL::text AS inf_app_name,
            NULL::text AS inf_folder,
            NULL::text AS inf_project,
            NULL::text AS inf_workflow,
            NULL::boolean AS kill_yarn_job_on_error,
            w1.name AS name_,
            p1.id AS profile_id,
            w1.profile AS profile_nm,
            w1.scheduled,
            w1.singleloading AS single_loading,
            NULL::text AS start_condition,
            w1.type,
            w1.wf_time_sched_active,
            w1.wf_time_sched_faulttolerance,
            w1.wf_time_sched_sched,
            w1.wf_time_sched_wf_id,
            w1.eff_from_dttm AS updated_dttm,
            row_number() OVER (PARTITION BY c1.id, w1.id ORDER BY w1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
             JOIN s_grnplm_as_cib_gm_ods_ctl.category c1 ON w1.category = c1.name
             LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON w1.profile = p1.name_::text
          WHERE 1 = 1 AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
                   FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
                  WHERE w2.id = w1.id)) AND c1.eff_to_dttm::date = '2999-12-31'::date) tt
  WHERE tt.rn_ = 1;


-- dg_full.vctl_wf_event_sched source

CREATE OR REPLACE VIEW dg_full.vctl_wf_event_sched
AS WITH tt AS (
         SELECT params.active,
            params.arg1,
            params.arg2,
            params.condition,
            w1.eff_from_dttm AS created_dttm,
            params.entity_id,
            p1.id AS profile_id,
            params.profile AS profile_nm,
            params.stat_id,
            params.stat_type,
            w1.eff_from_dttm AS updated_dttm,
            params.wf_id,
            row_number() OVER (PARTITION BY params.wf_id, params.entity_id ORDER BY w1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
             JOIN LATERAL json_populate_recordset(NULL::record, w1.wf_event_sched::json) params(arg1 text, stat_id text, condition text, profile text, entity_id text, arg2 text, stat_type text, wf_id text, active text) ON true
             LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_profile p1 ON w1.profile = p1.name_::text
          WHERE 1 = 1 AND w1.wf_event_sched IS NOT NULL AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
                   FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
                  WHERE w2.id = w1.id AND w2.wf_event_sched IS NOT NULL))
        )
 SELECT tt.active,
    tt.arg1,
    tt.arg2,
    tt.condition,
    tt.created_dttm,
    tt.entity_id,
    tt.profile_id,
    tt.profile_nm,
    tt.stat_id,
    tt.stat_type,
    tt.updated_dttm,
    tt.wf_id
   FROM tt
  WHERE tt.rn_ = 1;


-- dg_full.vctl_wf_event_startcond source

CREATE OR REPLACE VIEW dg_full.vctl_wf_event_startcond
AS WITH RECURSIVE json_extract AS (
         SELECT 1 AS level,
            'root'::text AS path,
            'or'::text AS node_type,
            NULL::bigint AS entity_id,
            NULL::text AS profile,
            NULL::text AS relevance_type,
            NULL::integer AS stat_id,
            src_data.wf_id,
            src_data.startcondition::json AS json_data
           FROM ( SELECT - 10::bigint AS wf_id,
                    '{"$type": "or", "inner": [{"$type": "statVal", "entityId": 902965604, "profile": "gp_cib_tib", "relevance": {"$type": "untilNextDate"}, "statId": 40}, {"$type": "and", "inner": [{"$type": "statVal", "entityId": 902964402, "profile": "gp_cib_core", "relevance": {"$type": "untilNextDate"}, "statId": 40}, {"$type": "statVal", "entityId": 902964404, "profile": "gp_cib_core", "relevance": {"$type": "untilNextDate"}, "statId": 40}, {"$type": "statVal", "entityId": 902964407, "profile": "gp_cib_core", "relevance": {"$type": "untilNextDate"}, "statId": 40}, {"$type": "statVal", "entityId": 902964390, "profile": "gp_cib_core", "relevance": {"$type": "untilNextDate"}, "statId": 40}, {"$type": "statVal", "entityId": 902964503, "profile": "gp_cib_core", "relevance": {"$type": "untilNextDate"}, "statId": 40}]}]}'::text AS startcondition
                UNION
                 SELECT w1.id AS wf_id,
                    w1.startcondition
                   FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
                  WHERE 1 = 1 AND w1.startcondition IS NOT NULL AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
                           FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
                          WHERE w2.id = w1.id AND w1.startcondition IS NOT NULL))) src_data
        UNION ALL
         SELECT je.level + 1 AS level,
            (je.path || '->'::text) || (elem.value ->> '$type'::text) AS path,
            elem.value ->> '$type'::text AS node_type,
            (elem.value ->> 'entityId'::text)::bigint AS entity_id,
            elem.value ->> 'profile'::text AS profile,
            (elem.value -> 'relevance'::text) ->> '$type'::text AS relevance_type,
            (elem.value ->> 'statId'::text)::integer AS stat_id,
            je.wf_id,
            elem.value AS json_data
           FROM json_extract je
             CROSS JOIN LATERAL json_array_elements(
                CASE
                    WHEN (je.json_data ->> '$type'::text) = ANY (ARRAY['or'::text, 'and'::text]) THEN je.json_data -> 'inner'::text
                    ELSE '[]'::json
                END) elem(value)
          WHERE je.level < 10 AND ((je.json_data ->> '$type'::text) = ANY (ARRAY['or'::text, 'and'::text]))
        ), json_unpacked_final AS (
         SELECT
                CASE
                    WHEN json_extract.level = 1 THEN 0
                    WHEN json_extract.level = 2 THEN 1
                    WHEN json_extract.level = 3 THEN
                    CASE
                        WHEN json_extract.path ~~ '%and->statVal%'::text THEN 3
                        ELSE 0
                    END
                    ELSE 0
                END AS parent_id,
            json_extract.node_type,
            json_extract.entity_id,
            json_extract.profile,
            json_extract.relevance_type,
            json_extract.stat_id,
            json_extract.level,
            json_extract.path,
            json_extract.wf_id
           FROM json_extract
          WHERE json_extract.node_type IS NOT NULL
          ORDER BY json_extract.level,
                CASE
                    WHEN json_extract.node_type = 'or'::text THEN 1
                    WHEN json_extract.node_type = 'statVal'::text AND json_extract.level = 2 THEN 2
                    WHEN json_extract.node_type = 'and'::text THEN 3
                    ELSE 4
                END
        )
 SELECT row_number() OVER (ORDER BY json_unpacked_final.level) AS node_id,
    json_unpacked_final.parent_id,
    json_unpacked_final.node_type,
    json_unpacked_final.entity_id,
    json_unpacked_final.profile,
    json_unpacked_final.relevance_type,
    json_unpacked_final.stat_id,
    json_unpacked_final.level,
    json_unpacked_final.path,
        CASE
            WHEN json_unpacked_final.parent_id = 0 THEN 'Корневой элемент'::text
            WHEN json_unpacked_final.parent_id = 1 THEN 'Дочерний элемент корня'::text
            ELSE 'Вложенный элемент'::text
        END AS hierarchy,
    json_unpacked_final.wf_id
   FROM json_unpacked_final
  ORDER BY row_number() OVER (ORDER BY json_unpacked_final.level);


-- dg_full.vctl_wf_params source

CREATE OR REPLACE VIEW dg_full.vctl_wf_params
AS WITH wf AS (
         SELECT w.category_id,
            w.profile_id,
            w.id,
            w.name_
           FROM dg_full.vctl_wf w
          WHERE 1 = 1 AND w.deleted = false AND (w.profile_id = ANY (ARRAY[329, 334, 74])) AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param) ~~ '%connectionlake%'::text AND cp1.prior_value ~~ '%TIB%'::text
                  GROUP BY cp1.wf_id))
        ), temp_wf0 AS (
         SELECT w.category_id,
            cc.name AS category_nm,
            w.profile_id,
            w.id AS wf_id,
            w.name_ AS wf_nm,
            cp.param,
            cp.prior_value,
                CASE
                    WHEN cp.param = ANY (ARRAY['tgt_entity_id'::text, 'entity_id'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS tgt_entity_id,
                CASE
                    WHEN cp.param = ANY (ARRAY['stg_schema_name'::text, 'stg_schema'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_espd_schema_name,
                CASE
                    WHEN cp.param = ANY (ARRAY['stg_table_name'::text, 'object_name'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_espd_table_name,
                CASE
                    WHEN cp.param = ANY (ARRAY['hive_schema_name'::text, 'hive_schema_name_act'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_hdp_schema_name,
                CASE
                    WHEN cp.param = ANY (ARRAY['hive_table_name'::text, 'hive_table_name_act'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_hdp_table_name,
                CASE
                    WHEN cp.param = 'hive_schema_name_act_snp'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_hdp_snp_schema_name,
                CASE
                    WHEN cp.param = 'hive_table_name_act_snp'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_hdp_snp_table_name,
                CASE
                    WHEN cp.param = 'hive_schema_name_act_diff'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_hdp_diff_schema_name,
                CASE
                    WHEN cp.param = 'hive_table_name_act_diff'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS src_hdp_diff_table_name,
                CASE
                    WHEN cp.param = ANY (ARRAY['function_schema'::text, 'ods_schema_name'::text, 'ods_schema'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS tgt_schema_name,
                CASE
                    WHEN cp.param = ANY (ARRAY['function_name'::text, 'ods_table_name'::text, 'object_name'::text]) THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS tgt_table_name,
                CASE
                    WHEN cp.param = 'function_name'::text THEN 'Function'::character varying
                    WHEN cp.param = ANY (ARRAY['ods_table_name'::text, 'object_name'::text]) THEN 'Table'::character varying
                    ELSE NULL::character varying
                END::text AS tgt_node_type_cd,
                CASE
                    WHEN cp.param = 'enable_dq'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS enable_dq,
                CASE
                    WHEN cp.param = 'column_key_list'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS column_key_list,
                CASE
                    WHEN cp.param = 'rin'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text AS column_rin,
            "substring"(
                CASE
                    WHEN cp.param = 'rin'::text THEN cp.prior_value::character varying
                    ELSE NULL::character varying
                END::text, ']_(.*?)_POSTGRESQL'::text) AS scenario_cd
           FROM wf w
             JOIN s_grnplm_as_cib_gm_ods_ctl.category cc ON w.category_id = cc.id
             JOIN dg_full.vctl_param cp ON w.id = cp.wf_id
          WHERE 1 = 1
        )
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
    max(w1.scenario_cd) AS scenario_cd,
    max(w1.column_rin) AS rin
   FROM temp_wf0 w1
  GROUP BY w1.category_id, w1.category_nm, w1.profile_id, w1.wf_id, w1.wf_nm;


-- dg_full.vctl_wf_time_sched source

CREATE OR REPLACE VIEW dg_full.vctl_wf_time_sched
AS WITH tt AS (
         SELECT w1.wf_time_sched_active AS active,
            w1.wf_time_sched_faulttolerance AS faulttolerance,
            w1.eff_from_dttm AS created_dttm,
            w1.wf_time_sched_sched AS sched,
            w1.eff_from_dttm AS updated_dttm,
            w1.wf_time_sched_wf_id AS wf_id,
            row_number() OVER (PARTITION BY w1.wf_time_sched_wf_id ORDER BY w1.eff_from_dttm DESC) AS rn_
           FROM s_grnplm_as_cib_gm_ods_ctl.wf w1
          WHERE 1 = 1 AND w1.wf_time_sched_wf_id IS NOT NULL AND w1.processing_id = (( SELECT max(w2.processing_id) AS max
                   FROM s_grnplm_as_cib_gm_ods_ctl.wf w2
                  WHERE w2.id = w1.id AND w2.wf_time_sched_wf_id IS NOT NULL))
        )
 SELECT tt.active,
    tt.faulttolerance,
    tt.created_dttm,
    tt.sched,
    tt.updated_dttm,
    tt.wf_id
   FROM tt
  WHERE tt.rn_ = 1;


-- dg_full.vhfact_lot_navigator source

CREATE OR REPLACE VIEW dg_full.vhfact_lot_navigator
AS WITH temp_desks_dkk AS (
         SELECT dkk_desks_dict.desk_id,
            dkk_desks_dict.desk_nm,
            dkk_desks_dict.desc_spik AS desk_nm_opu,
            dkk_desks_dict.desc_shot
           FROM s_grnplm_as_cib_gm_ods_spod_udlprod.dkk_desks_dict
          WHERE 1 = 1 AND dkk_desks_dict.dl_file_id::bigint = (( SELECT max(dkk_desks_dict_1.dl_file_id::bigint) AS max
                   FROM s_grnplm_as_cib_gm_ods_spod_udlprod.dkk_desks_dict dkk_desks_dict_1))
        )
 SELECT (lot.reporting_date + '1 mon'::interval - '1 day'::interval)::date AS reporting_date,
    lot.epk_id::text AS epk_id,
    lot.report_id::text AS report_id,
    cl.org_nm AS holding_nm,
    d.desc_shot AS desk_nm,
    cl.km_fio AS gkm_fio,
        CASE
            WHEN lot.level_of_trust = 5 THEN 'СО СБЕРОМ НАВСЕГДА'::text
            WHEN lot.level_of_trust = 4 THEN 'ДРУГ'::text
            WHEN lot.level_of_trust = 2 THEN 'ПРИЯТЕЛЬ'::text
            ELSE NULL::text
        END AS level_of_trust
   FROM s_grnplm_as_cib_gm_mart_tib.vhfact_clients_lot lot
     LEFT JOIN s_grnplm_as_cib_gm_mart_tib.hfact_tib_clients cl ON lot.epk_id = cl.epk_id AND cl.flg_calc = 'Daily'::text
     LEFT JOIN temp_desks_dkk d ON cl.desk_nm = d.desk_nm
  WHERE lot.card_type = 'Холдинг (не являющийся ЮЛ)'::text;


-- dg_full.vmeta_all_screen_link source

CREATE OR REPLACE VIEW dg_full.vmeta_all_screen_link
AS WITH grp AS (
         SELECT o.object_group_id,
            o.object_alias,
            og.object_group_name,
            og.object_group_descr,
            o.object_id,
            o.schema_src_id,
            o.table_src_id,
            o.attribute_src_id
           FROM dg_full.vmeta_object_group_ref_table og
             JOIN dg_full.vmeta_object_ref_table o ON og.object_group_id = o.object_group_id
        ), stmpl AS (
         SELECT st.screen_template_id,
            st.screen_category,
            st.descr,
            st.screen_sql,
            sta.object_alias AS sta_object_alias,
            sta.attribute_src_id AS sta_attribute_src_id,
                CASE
                    WHEN st.screen_template_id = ANY (ARRAY[13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73]) THEN p.priority_src_id
                    ELSE NULL::integer
                END AS priority_src_id,
                CASE
                    WHEN st.screen_template_id = ANY (ARRAY[13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73]) THEN p.priority_cd
                    ELSE NULL::text
                END AS priority_cd,
                CASE
                    WHEN st.screen_template_id = ANY (ARRAY[13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73]) THEN p.priority_nm
                    ELSE NULL::text
                END AS priority_nm
           FROM dg_full.meta_screen_template_ref_table st
             JOIN dg_full.meta_screen_template_alias_ref_table sta ON sta.screen_template_id = st.screen_template_id
             LEFT JOIN dg_full.meta_priority_ref_table p ON st.priority_cd = p.priority_cd
        ), tmp_screen AS (
         SELECT l.screen_id,
            l.screen_template_id,
            l.object_group_id,
            stmpl.screen_category,
            stmpl.descr,
            stmpl.screen_sql,
            stmpl.sta_object_alias,
            stmpl.sta_attribute_src_id,
            grp.object_group_name,
            grp.object_group_descr,
            grp.object_id,
            grp.schema_src_id,
            grp.table_src_id,
            grp.attribute_src_id,
            grp.object_alias,
                CASE
                    WHEN grp.attribute_src_id IS NULL THEN stmpl.priority_src_id
                    ELSE NULL::integer
                END AS priority_src_id,
                CASE
                    WHEN grp.attribute_src_id IS NULL THEN stmpl.priority_cd
                    ELSE NULL::text
                END AS priority_cd,
                CASE
                    WHEN grp.attribute_src_id IS NULL THEN stmpl.priority_nm
                    ELSE NULL::text
                END AS priority_nm,
            l.exception_group_id
           FROM dg_full.vmeta_screen_link l
             LEFT JOIN stmpl ON stmpl.screen_template_id = l.screen_template_id
             JOIN grp ON grp.object_group_id = l.object_group_id AND grp.object_alias = stmpl.sta_object_alias
          WHERE 1 = 1
        ), tmp_sever AS (
         SELECT s.schema_src_id,
            s.table_src_id,
            s.screen_template_id,
            max(s.priority_src_id) AS severity,
            max(s.priority_src_id)::real / count(*)::real AS severity_cn
           FROM tmp_screen s
          WHERE 1 = 1 AND s.priority_src_id IS NOT NULL
          GROUP BY s.schema_src_id, s.table_src_id, s.screen_template_id
        )
 SELECT s1.screen_id,
    s1.screen_template_id,
    s1.object_group_id,
    s1.screen_category,
    s1.descr,
    s1.screen_sql,
    s1.sta_object_alias,
    s1.sta_attribute_src_id,
    s1.object_group_name,
    s1.object_group_descr,
    s1.object_id,
    s1.schema_src_id,
    s1.table_src_id,
    s1.attribute_src_id,
    s1.object_alias,
    s1.priority_src_id,
    s1.priority_cd,
    s1.priority_nm,
    s2.severity_cn,
    s1.exception_group_id
   FROM tmp_screen s1
     LEFT JOIN tmp_sever s2 ON s1.schema_src_id::text = s2.schema_src_id::text AND s1.table_src_id::text = s2.table_src_id::text AND s1.screen_template_id = s2.screen_template_id AND s1.priority_src_id = s2.severity;


-- dg_full.vmeta_check_duration source

CREATE OR REPLACE VIEW dg_full.vmeta_check_duration
AS WITH st1 AS (
         SELECT pgn.nspname AS schema_src_id,
            pgc.relname AS node_src_id,
                CASE
                    WHEN pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char"]) THEN 1
                    WHEN pgc.relkind = 'v'::"char" THEN 2
                    WHEN pgc.relkind = 'm'::"char" THEN 3
                    ELSE NULL::integer
                END AS node_type_src_id
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN s_grnplm_as_cib_gm_dg.meta_schema_ref_table s ON pgn.nspname = s.schema_cd::name
          WHERE 1 = 1 AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"])) AND (pgn.nspname <> ALL (ARRAY['s_grnplm_as_cib_gm_ods_spod_udlprod'::name, 's_grnplm_as_cib_gm_meta'::name, 's_grnplm_as_cib_gm_dv'::name])) AND pgn.nspname !~~ '%_ld_%'::text AND pgn.nspname !~~ '%_stg_%'::text
        ), st2 AS (
         SELECT max(n.started) AS start_dt,
            max(n.avg_ods_duration_sec) AS avg_ods_duration_sec,
            max(n.stddev_ods_duration_sec) AS stddev_ods_duration_sec,
            n.nspname,
            n.relname
           FROM dg_full.vmeta_get_metrics n
          GROUP BY n.nspname, n.relname
        )
 SELECT st1.schema_src_id,
    st1.node_src_id,
    st1.node_type_src_id,
    st2.start_dt,
    st2.nspname,
    st2.relname,
    st2.avg_ods_duration_sec,
    st2.stddev_ods_duration_sec
   FROM st1
     LEFT JOIN st2 ON st1.schema_src_id::text = st2.nspname AND st1.node_src_id::text = st2.relname
  WHERE 1 = 1 AND st1.node_type_src_id = 1;

COMMENT ON VIEW dg_full.vmeta_check_duration IS 'Проверка фактического времени загрузки';
COMMENT ON COLUMN dg_full.vmeta_check_duration.schema_src_id IS 'Схема из метаданных GP';
COMMENT ON COLUMN dg_full.vmeta_check_duration.node_src_id IS 'Объект из метаданных GP';
COMMENT ON COLUMN dg_full.vmeta_check_duration.node_type_src_id IS 'Тип объекта из метаданных GP';
COMMENT ON COLUMN dg_full.vmeta_check_duration.start_dt IS 'Начало загрузки объекта';
COMMENT ON COLUMN dg_full.vmeta_check_duration.nspname IS 'Схема из метрик';
COMMENT ON COLUMN dg_full.vmeta_check_duration.relname IS 'Объект из метрик';
COMMENT ON COLUMN dg_full.vmeta_check_duration.avg_ods_duration_sec IS 'Среднее время загрузки объекта';
COMMENT ON COLUMN dg_full.vmeta_check_duration.stddev_ods_duration_sec IS 'Срднеквдр.отклонение загрузки объекта';


-- dg_full.vmeta_check_kkd_duration source

CREATE OR REPLACE VIEW dg_full.vmeta_check_kkd_duration
AS SELECT dl.run_tm::date AS report_dt,
    dl.wf_load_id,
    dl.wf_id,
    wf.name_ AS wf_nm,
    min(dl.run_tm) AS start_dttm,
    max(dl.run_tm) AS end_dttm,
    max(dl.run_tm) - min(dl.run_tm) AS diff_dttm
   FROM s_grnplm_as_cib_gm_meta.dev_logs dl
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_wf wf ON dl.wf_id = wf.id
  WHERE 1 = 1 AND dl.proc_name = 'return_meta_run_batch'::text
  GROUP BY dl.run_tm::date, dl.wf_load_id, dl.wf_id, wf.name_;


-- dg_full.vmeta_check_scheduler source

CREATE OR REPLACE VIEW dg_full.vmeta_check_scheduler
AS WITH st2 AS (
         SELECT s.schema_src_id AS nspname,
            s.node_src_id AS relname,
            s.period_type_comment,
            dg_full.meta_match(now(), COALESCE(s.period_type_comment, '0 12 * * 1-5'::text)) AS now_period_type_match,
            s.every_times,
            s.period_refresh_comment,
            s.source_object,
            st.descr AS period_type_name
           FROM dg_full.meta_scheduler_hsat s
             JOIN dg_full.meta_scheduler_type_ref_table st ON st.scheduler_type_src_id::text = s.scheduler_type_src_id::text
        ), st3 AS (
         SELECT l.src_schema_src_id AS schema_src_id,
            l.src_node_src_id AS node_src_id,
            l.src_node_type_cd AS node_type_cd,
            src.nspname,
            src.relname,
            src.period_type_comment,
            src.now_period_type_match,
            src.every_times,
            src.period_refresh_comment
           FROM dg_full.meta_edge_link l
             LEFT JOIN st2 src ON l.src_schema_src_id::name = src.nspname::name AND l.src_node_src_id::name = src.relname::name
          WHERE 1 = 1
        UNION
         SELECT l.target_schema_src_id AS schema_src_id,
            l.target_node_src_id AS node_src_id,
            l.tgt_node_type_cd AS node_type_cd,
            tgt.nspname,
            tgt.relname,
            tgt.period_type_comment,
            tgt.now_period_type_match,
            tgt.every_times,
            tgt.period_refresh_comment
           FROM dg_full.meta_edge_link l
             LEFT JOIN st2 tgt ON l.target_schema_src_id::name = tgt.nspname::name AND l.target_node_src_id::name = tgt.relname::name
          WHERE 1 = 1
        )
 SELECT st3.schema_src_id::name AS schema_src_id,
    st3.node_src_id::name AS node_src_id,
    st3.node_type_cd,
    st3.period_type_comment,
    st3.now_period_type_match,
    st3.every_times,
    st3.period_refresh_comment
   FROM st3
  WHERE (1 = 1 AND st3.nspname IS NULL) OR (st3.period_type_comment IS NULL AND st3.period_refresh_comment !~~ '%wf_event_sched%'::text);

COMMENT ON VIEW dg_full.vmeta_check_scheduler IS 'Проверка наличия расписания';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.schema_src_id IS 'Схема';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.node_src_id IS 'Объект';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.node_type_cd IS 'Тип объекта';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.period_type_comment IS 'Расписание cron';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.now_period_type_match IS 'Дельта между NOW и расписанием';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.every_times IS 'Приоритет';
COMMENT ON COLUMN dg_full.vmeta_check_scheduler.period_refresh_comment IS 'Связь с ЕСПД';


-- dg_full.vmeta_check_screen_link source

CREATE OR REPLACE VIEW dg_full.vmeta_check_screen_link
AS WITH grp AS (
         SELECT o.object_group_id,
            o.object_alias,
            og.object_group_name,
            og.object_group_descr,
            o.object_id,
            o.schema_src_id,
            o.table_src_id,
            o.attribute_src_id
           FROM dg_full.meta_object_group_ref_table og
             JOIN dg_full.meta_object_ref_table o ON og.object_group_id = o.object_group_id
        ), stmpl AS (
         SELECT st.screen_template_id,
            st.screen_category,
            st.descr,
            st.screen_sql,
            sta.object_alias AS sta_object_alias,
            sta.attribute_src_id AS sta_attribute_src_id
           FROM dg_full.meta_screen_template_ref_table st
             JOIN dg_full.meta_screen_template_alias_ref_table sta ON sta.screen_template_id = st.screen_template_id
        )
 SELECT l.screen_id,
    l.screen_template_id,
    l.object_group_id,
    stmpl.screen_category,
    stmpl.descr,
    stmpl.screen_sql,
    stmpl.sta_object_alias,
    stmpl.sta_attribute_src_id,
    grp.object_group_name,
    grp.object_group_descr,
    grp.object_id,
    grp.schema_src_id,
    grp.table_src_id,
    grp.attribute_src_id,
    grp.object_alias,
    l.exception_group_id
   FROM dg_full.meta_screen_link l
     LEFT JOIN stmpl ON stmpl.screen_template_id = l.screen_template_id
     FULL JOIN grp ON grp.object_group_id = l.object_group_id AND grp.object_alias = stmpl.sta_object_alias
  WHERE 1 = 1 AND (grp.object_group_id IS NULL OR grp.object_id IS NULL OR grp.object_alias IS NULL);


-- dg_full.vmeta_check_wf_load_id source

CREATE OR REPLACE VIEW dg_full.vmeta_check_wf_load_id
AS WITH hfact_cread_all_seg AS (
         SELECT hfact_tib_cred.wf_load_id
           FROM s_grnplm_as_cib_gm_mart_tib_lpm.hfact_tib_cred
          GROUP BY hfact_tib_cred.wf_load_id
        ), hfact_tib_clients AS (
         SELECT hfact_tib_clients.wf_load_id
           FROM s_grnplm_as_cib_gm_mart_tib.hfact_tib_clients
          GROUP BY hfact_tib_clients.wf_load_id
        ), hfact_tib_forecast_issue_and_repay AS (
         SELECT hfact_tib_forecast_issue_and_repay.wf_load_id
           FROM s_grnplm_as_cib_gm_mart_tib.hfact_tib_forecast_issue_and_repay
          GROUP BY hfact_tib_forecast_issue_and_repay.wf_load_id
        ), hfact_tib_issue_and_repay_sred_plus AS (
         SELECT hfact_tib_issue_and_repay_sred_plus.wf_load_id
           FROM s_grnplm_as_cib_gm_mart_tib.hfact_tib_issue_and_repay_sred_plus
          GROUP BY hfact_tib_issue_and_repay_sred_plus.wf_load_id
        ), btch AS (
         SELECT f.batch_id,
            f.screen_id,
            f.schema_src_id,
            f.table_src_id,
            f.record_identifier ->> 'wf_load_id'::text AS arr_wf_load_id,
            json_array_elements_text(f.record_identifier -> 'wf_load_id'::text) AS wf_load_id,
            date_trunc('day'::text, f.load_dttm)::date AS load_date
           FROM dg_full.meta_error_event_fact f
          WHERE 1 = 1 AND f.record_identifier::jsonb ?| ARRAY['wf_load_id'::text]
          GROUP BY f.batch_id, f.screen_id, f.schema_src_id, f.table_src_id, f.record_identifier ->> 'wf_load_id'::text, json_array_elements_text(f.record_identifier -> 'wf_load_id'::text), date_trunc('day'::text, f.load_dttm)::date
        ), btch1 AS (
         SELECT b.batch_id,
            b.screen_id,
            b.schema_src_id,
            b.table_src_id,
            b.arr_wf_load_id,
            b.load_date,
            count(
                CASE
                    WHEN w1.wf_load_id IS NOT NULL THEN 1
                    ELSE NULL::integer
                END) OVER (PARTITION BY b.batch_id, b.screen_id, b.schema_src_id, b.table_src_id) AS w1_flg,
            count(
                CASE
                    WHEN w2.wf_load_id IS NOT NULL THEN 1
                    ELSE NULL::integer
                END) OVER (PARTITION BY b.batch_id, b.screen_id, b.schema_src_id, b.table_src_id) AS w2_flg,
            count(
                CASE
                    WHEN w3.wf_load_id IS NOT NULL THEN 1
                    ELSE NULL::integer
                END) OVER (PARTITION BY b.batch_id, b.screen_id, b.schema_src_id, b.table_src_id) AS w3_flg,
            count(
                CASE
                    WHEN w4.wf_load_id IS NOT NULL THEN 1
                    ELSE NULL::integer
                END) OVER (PARTITION BY b.batch_id, b.screen_id, b.schema_src_id, b.table_src_id) AS w4_flg,
            count(*) OVER (PARTITION BY b.batch_id, b.screen_id, b.schema_src_id, b.table_src_id) AS cnt
           FROM btch b
             LEFT JOIN hfact_cread_all_seg w1 ON w1.wf_load_id = b.wf_load_id::bigint
             LEFT JOIN hfact_tib_clients w2 ON w2.wf_load_id = b.wf_load_id::bigint
             LEFT JOIN hfact_tib_forecast_issue_and_repay w3 ON w3.wf_load_id = b.wf_load_id::bigint
             LEFT JOIN hfact_tib_issue_and_repay_sred_plus w4 ON w4.wf_load_id = b.wf_load_id::bigint
        )
 SELECT b1.batch_id,
    b1.screen_id,
    b1.schema_src_id,
    b1.table_src_id,
    b1.arr_wf_load_id,
    b1.load_date,
    b1.w1_flg / b1.cnt * 100 AS cred_prc,
    b1.w2_flg / b1.cnt * 100 AS clients_prc,
    b1.w3_flg / b1.cnt * 100 AS plan_oper_prc,
    b1.w4_flg / b1.cnt * 100 AS fact_oper_prc
   FROM btch1 b1;


-- dg_full.vmeta_ctl_hierarchy source

CREATE OR REPLACE VIEW dg_full.vmeta_ctl_hierarchy
AS WITH RECURSIVE search_graph(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parent_id,
            g.name_::text AS name_,
            1 AS depth,
            ARRAY[g.name_::text] AS path,
            false AS cycle,
            g.name_ AS root_name_id
           FROM s_grnplm_as_cib_gm_stg_espd.ctl_category g
          WHERE 1 = 1 AND g.parent_id = 0 AND g.id = 1764 AND g.deleted = false
        UNION ALL
         SELECT g1.id,
            g1.parent_id,
            g1.name_::text AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name_::text,
            g1.name_::text = ANY (p.path),
            p.root_name_id
           FROM s_grnplm_as_cib_gm_stg_espd.ctl_category g1
             JOIN search_graph p ON p.id = g1.parent_id
          WHERE 1 = 1 AND NOT p.cycle
        )
 SELECT
        CASE
            WHEN w.profile_id = 329 THEN 'gp_cib_core'::text
            WHEN w.profile_id = 334 THEN 'gp_cib_tib'::text
            WHEN w.profile_id = 74 THEN 'gp_cib'::text
            ELSE NULL::text
        END AS profile_name,
    cc.name_ AS cc_name,
    w.name_ AS wf_name,
    w.scheduled,
    w.single_loading,
    cwes.active AS cwes_active,
    cwes.condition,
    cwes.stat_id,
    cwes.stat_type,
    cwts.active AS cwts_active,
    cwts.sched
   FROM search_graph cc
     JOIN s_grnplm_as_cib_gm_stg_espd.ctl_wf w ON cc.id = w.category_id
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_wf_event_sched cwes ON w.id = cwes.wf_id
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.ctl_wf_time_sched cwts ON w.id = cwts.wf_id
  WHERE 1 = 1 AND (w.profile_id = ANY (ARRAY[329, 334, 74])) AND w.deleted = false
  GROUP BY
        CASE
            WHEN w.profile_id = 329 THEN 'gp_cib_core'::text
            WHEN w.profile_id = 334 THEN 'gp_cib_tib'::text
            WHEN w.profile_id = 74 THEN 'gp_cib'::text
            ELSE NULL::text
        END, cc.name_, w.name_, w.scheduled, w.single_loading, cwes.active, cwes.condition, cwes.stat_id, cwes.stat_type, cwts.active, cwts.sched;


-- dg_full.vmeta_data_catalog source

CREATE OR REPLACE VIEW dg_full.vmeta_data_catalog
AS WITH constraint_ AS (
         SELECT c.conrelid,
            c.conkey,
            c.contype,
            cols.colnum
           FROM pg_constraint c
             CROSS JOIN LATERAL unnest(c.conkey) cols(colnum)
          ORDER BY c.conrelid
        ), partition_ AS (
         SELECT p_1.parrelid,
            p_1.parlevel,
            p_1.paratts[i.i] AS attnum,
            i.i
           FROM pg_partition p_1,
            generate_series(0, ( SELECT max(array_upper(pg_partition.paratts, 1)) AS max
                   FROM pg_partition)) i(i)
          WHERE p_1.paratts[i.i] IS NOT NULL
        ), lst AS (
         SELECT pgn.nspname::text AS "T-schema",
            NULL::text AS "T-table",
            NULL::text AS "T-col",
            obj_description(pgn.oid) AS "T-note",
            'SCHEMA'::text AS "T-type",
            NULL::text AS "T-col-null",
            NULL::text AS "T-col-pk",
            NULL::text AS "T-col-fk",
            NULL::text AS "codePartition"
           FROM pg_namespace pgn
        UNION
         SELECT pgn.nspname::text AS "T-schema",
            pgc.relname::text AS "T-table",
            NULL::text AS "T-col",
            obj_description(pgc.oid) AS "T-note",
                CASE pgc.relkind
                    WHEN 'r'::"char" THEN 'TABLE'::text
                    WHEN 'p'::"char" THEN 'TABLE'::text
                    WHEN 'v'::"char" THEN 'VIEW'::text
                    WHEN 'm'::"char" THEN 'VIEW'::text
                    ELSE NULL::text
                END AS "T-type",
            NULL::text AS "T-col-null",
            NULL::text AS "T-col-pk",
            NULL::text AS "T-col-fk",
            NULL::text AS "codePartition"
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
          WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        UNION
         SELECT pgn.nspname::text AS "T-schema",
            pgc.relname::text AS "T-table",
            a.attname::text AS "T-col",
            col_description(pgc.oid, a.attnum::integer) AS "T-note",
            format_type(a.atttypid, a.atttypmod) AS "T-type",
                CASE
                    WHEN a.attnotnull IS TRUE THEN 'NOT NULL'::text
                    ELSE 'NULL'::text
                END AS "T-col-null",
                CASE
                    WHEN cp.conrelid IS NOT NULL THEN 'Y'::text
                    ELSE 'N'::text
                END AS "T-col-pk",
                CASE
                    WHEN cf.conrelid IS NOT NULL THEN 'Y'::text
                    ELSE 'N'::text
                END AS "T-col-fk",
                CASE
                    WHEN p.parrelid IS NOT NULL THEN a.attname
                    ELSE NULL::name
                END::text AS "codePartition"
           FROM pg_attribute a
             JOIN pg_class pgc ON a.attrelid = pgc.oid
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             LEFT JOIN constraint_ cp ON a.attrelid = cp.conrelid AND a.attnum = cp.colnum AND cp.contype = 'p'::"char"
             LEFT JOIN constraint_ cf ON a.attrelid = cf.conrelid AND a.attnum = cf.colnum AND cp.contype = 'f'::"char"
             LEFT JOIN partition_ p ON p.parrelid = pgc.oid AND p.attnum = a.attnum
          WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND a.attnum > 0 AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        )
 SELECT lst."T-schema",
    lst."T-table",
    lst."T-col",
    lst."T-note",
    lst."T-type",
    lst."T-col-null",
    lst."T-col-pk",
    lst."T-col-fk",
    lst."codePartition",
    s.type AS contur_type
   FROM lst
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name::text = lst."T-schema";


-- dg_full.vmeta_data_catalog_attribute source

CREATE OR REPLACE VIEW dg_full.vmeta_data_catalog_attribute
AS SELECT s2t."T-schema",
    s2t."T-schema-note",
    s2t."T-name",
    COALESCE(s2t."T-note", smd.tb_name) AS tb_comment,
    s2t."T-col-name",
    s2t."T-col-type",
    COALESCE(s2t."T-col-note", smd.name) AS attr_comment
   FROM dg_full.vmeta_s2t_meta_target_columns s2t
     LEFT JOIN dg_full.meta_schema_ref_table msrt ON s2t."T-schema" = msrt.schema_src_id::text
     LEFT JOIN ( SELECT max(att.eff_date_ts) AS eff_date_ts,
            att.is_active_flg,
            att.model_element_type_name,
            att.name,
            att.pm_data_type,
            att.pm_name,
            att.stock_element_id_atr,
            att.stock_element_id_ent,
            tb.name AS tb_name,
            tb.pm_name AS tb_pm_name
           FROM s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_attribute att
             JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table tb ON att.stock_element_id_ent = tb.stock_element_id_ent
          WHERE 1 = 1
          GROUP BY att.eff_date_ts, att.is_active_flg, att.model_element_type_name, att.name, att.pm_data_type, att.pm_name, att.stock_element_id_atr, att.stock_element_id_ent, tb.name, tb.pm_name) smd ON smd.tb_pm_name = upper(s2t."T-name") AND upper(s2t."T-col-name") = smd.pm_name
  GROUP BY s2t."T-schema", s2t."T-schema-note", s2t."T-name", COALESCE(s2t."T-note", smd.tb_name), s2t."T-col-name", s2t."T-col-type", COALESCE(s2t."T-col-note", smd.name);


-- dg_full.vmeta_data_catalog_data_product source

CREATE OR REPLACE VIEW dg_full.vmeta_data_catalog_data_product
AS SELECT nd.src_cd,
    COALESCE(s2t."T-note", smd.name) AS busines_name,
    nd.schema_src_id,
    nd.node_src_id,
    '-' AS descr,
    nd.node_type_cd,
    pl.period_type_comment,
        CASE
            WHEN pl.period_refresh_comment ~~ '%Запуск%'::text THEN 'Активна'::text
            WHEN pl.period_refresh_comment ~~ '%Останов%'::text AND pl.is_wf_time_sched_active IS FALSE THEN 'Архив'::text
            ELSE 'Активна'::text
        END AS status,
    '-' AS linkfsd,
    '-' AS customer,
    '-' AS developer,
    '-' AS tag
   FROM dg_full.meta_node_ref_table nd
     LEFT JOIN dg_full.vmeta_s2t_meta_target_columns s2t ON s2t."T-schema" = nd.schema_src_id::text AND s2t."T-name" = nd.node_src_id::text
     LEFT JOIN s_grnplm_as_cib_gm_dg.meta_scheduler_plan pl ON pl.node_src_id = nd.node_src_id::text AND pl.schema_src_id = nd.schema_src_id::text
     LEFT JOIN s_grnplm_as_cib_gm_stg_espd.v_smd_dataproduct_table smd ON lower(smd.pm_name) = nd.node_src_id::text
  WHERE nd.schema_src_id::text !~~ '%_ld_%'::text
  GROUP BY nd.src_cd, COALESCE(s2t."T-note", smd.name), nd.schema_src_id, nd.node_src_id, nd.node_type_cd,
        CASE
            WHEN pl.period_refresh_comment ~~ '%Запуск%'::text THEN 'Активна'::text
            WHEN pl.period_refresh_comment ~~ '%Останов%'::text AND pl.is_wf_time_sched_active IS FALSE THEN 'Архив'::text
            ELSE 'Активна'::text
        END, pl.period_type_comment
  ORDER BY nd.src_cd, COALESCE(s2t."T-note", smd.name);


-- dg_full.vmeta_dq_alerts source

CREATE OR REPLACE VIEW dg_full.vmeta_dq_alerts
AS SELECT st.schema_src_id,
    st.node_src_id,
    st.period_type_comment,
    st.period_refresh_comment,
    st.plan_trg,
    st.fact_started,
    st.fact_ended,
    st.err_stts_ods,
    st.ready_finished_fl,
    st.max_fact_dttm,
    dq.unit,
    dq.attr,
    dq.record_error,
    dq.final_severity_score,
    dq.red_flg,
    dq.metric,
    dq.load_dttm,
    dq.max_date
   FROM ( SELECT vmeta_scheduler_plan_fact.schema_src_id,
            vmeta_scheduler_plan_fact.node_src_id,
            vmeta_scheduler_plan_fact.period_type_comment,
            vmeta_scheduler_plan_fact.period_refresh_comment,
            vmeta_scheduler_plan_fact.plan_trg,
            vmeta_scheduler_plan_fact.fact_started,
            vmeta_scheduler_plan_fact.fact_ended,
            vmeta_scheduler_plan_fact.err_stts_ods,
            vmeta_scheduler_plan_fact.ready_finished_fl,
            vmeta_scheduler_plan_fact.max_fact_dttm
           FROM dg_full.vmeta_scheduler_plan_fact
          WHERE vmeta_scheduler_plan_fact.schema_src_id = 's_grnplm_as_cib_gm_mart_tib'::text AND (vmeta_scheduler_plan_fact.node_src_id = ANY (ARRAY['hfact_tib_issue_and_repay_sred_plus'::text, 'hfact_tib_issue_and_repay_sred_plus_pprb'::text]))) st
     LEFT JOIN ( SELECT t1.load_dttm,
            t1.table_src_id,
            t1.schema_src_id,
            t1.record_identifier ->> 'reporting_date'::text AS reporting_date,
            t1.record_identifier ->> 'unit'::text AS unit,
            t1.record_identifier ->> 'client_id'::text AS client_id,
            t1.record_identifier ->> 'attr'::text AS attr,
            t1.record_identifier ->> 'max_date'::text AS max_date,
            t1.record_error,
            ex.red_flg,
            t1.final_severity_score,
            t1.metric
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact t1
             LEFT JOIN ( SELECT vmeta_exception_action_ref_table.exception_action_id,
                    vmeta_exception_action_ref_table.exception_action_name,
                    vmeta_exception_action_ref_table.load_dttm,
                    vmeta_exception_action_ref_table.wf_load_id,
                    vmeta_exception_action_ref_table.src_cd,
                    vmeta_exception_action_ref_table.exception_action_descr,
                    vmeta_exception_action_ref_table.exception_group_id,
                    vmeta_exception_action_ref_table.prc_from,
                    vmeta_exception_action_ref_table.prc_to,
                    vmeta_exception_action_ref_table.action_gradient,
                    vmeta_exception_action_ref_table.interval_rank,
                    vmeta_exception_action_ref_table.red_interval_prc_to,
                    vmeta_exception_action_ref_table.red_flg
                   FROM dg_full.vmeta_exception_action_ref_table) ex ON ex.exception_action_id = t1.exception_action_id
          WHERE 1 = 1 AND (t1.table_src_id::text = ANY (ARRAY['hfact_tib_issue_and_repay_sred_plus'::character varying, 'hfact_tib_issue_and_repay_sred_plus_pprb'::character varying]::text[])) AND ((t1.record_identifier ->> 'unit'::text) = ANY (ARRAY['%'::text, 'cnt'::text]))) dq ON st.node_src_id = dq.table_src_id::text AND st.schema_src_id = dq.schema_src_id::text AND date_trunc('day'::text, st.plan_trg) = date_trunc('day'::text, dq.load_dttm)
  WHERE 1 = 1 AND date_trunc('day'::text, st.plan_trg) = (( SELECT max(date_trunc('day'::text, meta_error_event_fact.load_dttm)) AS max
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact
          WHERE meta_error_event_fact.table_src_id::text = ANY (ARRAY['hfact_tib_issue_and_repay_sred_plus'::character varying, 'hfact_tib_issue_and_repay_sred_plus_pprb'::character varying]::text[])))
  GROUP BY st.schema_src_id, st.node_src_id, st.period_type_comment, st.period_refresh_comment, st.plan_trg, st.fact_started, st.fact_ended, st.err_stts_ods, st.ready_finished_fl, st.max_fact_dttm, dq.unit, dq.attr, dq.record_error, dq.final_severity_score, dq.red_flg, dq.metric, dq.load_dttm, dq.max_date;


-- dg_full.vmeta_dq_dependences source

CREATE OR REPLACE VIEW dg_full.vmeta_dq_dependences
AS WITH t AS (
         SELECT olink.schema_src_id AS sch_name,
            olink.node_src_id AS tbl_name,
            olink.node_type_cd,
            date_trunc('day'::text, plan.plan_trg) AS plan_trg,
            COALESCE(max(plan.ready_str), 'null'::text) AS readystr
           FROM dg_full.meta_search_graph_target_all_obj olink
             LEFT JOIN dg_full.vmeta_scheduler_plan_fact plan ON olink.node_src_id = plan.node_src_id AND olink.schema_src_id = plan.schema_src_id AND olink.node_type_cd::text = plan.node_type_cd::text
          WHERE 1 = 1 AND olink.root_node_src_id = 'hfact_tib_issue_and_repay_sred_plus'::text AND date_trunc('day'::text, plan.plan_trg) = date_trunc('day'::text, now()) AND olink.node_type_cd::text = 'Table'::text
          GROUP BY olink.schema_src_id, olink.node_src_id, olink.node_type_cd, olink.root_schema_src_id, olink.root_node_src_id, olink.root_node_type_cd, plan.node_type_cd, date_trunc('day'::text, plan.plan_trg)
        )
 SELECT t.sch_name,
    t.tbl_name,
    t.node_type_cd,
    t.plan_trg,
    t.readystr
   FROM t
  WHERE t.readystr = 'red'::text;


-- dg_full.vmeta_dq_opu source

CREATE OR REPLACE VIEW dg_full.vmeta_dq_opu
AS SELECT t1.load_dttm,
    t1.table_src_id,
    t1.record_identifier ->> 'actdate'::text AS actdate,
    t1.record_identifier ->> 'unit'::text AS unit,
    t1.record_identifier ->> 'opu_code'::text AS opu_code,
    t1.record_identifier ->> 'pldate'::text AS pldate,
    t1.record_identifier ->> 'factlayercode'::text AS factlayercode,
    t1.record_identifier ->> 'segm'::text AS segm,
    t1.record_identifier ->> 'report_id'::text AS report_id,
    t1.record_identifier ->> 'sum_fact'::text AS sum_fact,
    t1.record_identifier ->> 'report_id_fac'::text AS report_id_fac,
    t1.record_identifier ->> 'total_sum'::text AS total_sum,
    t1.record_identifier ->> 'layercode'::text AS layercode,
    t1.record_identifier ->> 'cust_nm_full'::text AS cust_nm_full,
    t1.record_identifier ->> 'foreclayercode'::text AS foreclayercode,
    t1.record_identifier ->> 'sum_tot'::text AS sum_tot,
    t1.record_identifier ->> 'sum_lag_tot'::text AS sum_lag_tot,
    t1.record_identifier ->> 'report_id_cnt_fact'::text AS report_id_cnt_fact,
    t1.record_identifier ->> 'sum_forec'::text AS sum_forec,
    t1.record_identifier ->> 'lag_month'::text AS lag_month,
    t1.record_identifier ->> 'layercode_forecast'::text AS layercode_forecast,
    t1.record_identifier ->> 'dif_sum'::text AS dif_summ,
    t1.record_identifier ->> 'factlag_month'::text AS factlag_month,
    t1.record_identifier ->> 'perc_dif_summ'::text AS perc_dif_summ,
    t1.record_identifier ->> 'lag_report_id_cnt_fact'::text AS lag_report_id_cnt_fact,
    t1.record_identifier ->> 'lag_sum_fact'::text AS lag_sum_fact,
    t1.record_identifier ->> 'dif_fact_report'::text AS dif_fact_report,
    t1.record_identifier ->> 'dif_fact_sum'::text AS dif_fact_sum,
    t1.record_identifier ->> 'total_fact'::text AS total_fact,
    t1.record_identifier ->> 'report_id_cnt_forecast'::text AS report_id_cnt_forecast,
    t1.record_identifier ->> 'sum_forecast'::text AS sum_forecast,
    t1.record_identifier ->> 'lag_report_id_cnt_forecast'::text AS lag_report_id_cnt_forecast,
    t1.record_identifier ->> 'lag_sum_forecast'::text AS lag_sum_forecast,
    t1.record_identifier ->> 'dif_forecast_report'::text AS dif_forecast_report,
    t1.record_identifier ->> 'dif_forecast_sum'::text AS dif_forecast_sum,
    t1.record_identifier ->> 'sum_od'::text AS sum_od,
    t1.record_identifier ->> 'err_fl_fact'::text AS err_fl_fact,
    t1.record_identifier ->> 'err_fl_forecast'::text AS err_fl_forecast,
    t1.record_identifier ->> 'report_id_cnt'::text AS report_id_cnt,
    t1.record_error,
    t1.metric,
    t1.batch_id,
    t1.record_identifier ->> 'lag_month_actdt'::text AS lag_month_actdt
   FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact t1
  WHERE 1 = 1 AND (t1.table_src_id::text = 'dkk_data_arc'::text OR t1.table_src_id::text = 'v_dkk_data_arc_oper_slice'::text);


-- dg_full.vmeta_dq_statistic source

CREATE OR REPLACE VIEW dg_full.vmeta_dq_statistic
AS WITH days10 AS (
         SELECT ts_report.ts_report::date AS start_dt
           FROM generate_series((now()::date - '10 days'::interval)::date::timestamp with time zone, now()::date::timestamp with time zone, '1 day'::interval) ts_report(ts_report)
        ), tbl_sched AS (
         SELECT p.plan_dt,
            p.schema_src_id,
            count(DISTINCT (p.schema_src_id || '||'::text) || p.node_src_id) AS plan_ttl_cn,
            count(DISTINCT
                CASE
                    WHEN ((p.schema_src_id, p.node_src_id) IN ( SELECT o.schema_src_id,
                        o.table_src_id
                       FROM dg_full.vmeta_object_ref_table o
                      GROUP BY o.schema_src_id, o.table_src_id)) THEN (p.schema_src_id || '||'::text) || p.node_src_id
                    ELSE NULL::text
                END) AS plan_kkd_ttl_cn,
            count(DISTINCT
                CASE
                    WHEN ((p.plan_dt, p.schema_src_id, p.node_src_id) IN ( SELECT f_1.load_dttm::date AS load_dttm,
                        f_1.schema_src_id,
                        f_1.table_src_id
                       FROM dg_full.meta_error_event_fact f_1
                      GROUP BY f_1.load_dttm::date, f_1.schema_src_id, f_1.table_src_id)) THEN (p.schema_src_id || '||'::text) || p.node_src_id
                    ELSE NULL::text
                END) AS fact_kkd_ttl_cn,
            now()::date::timestamp without time zone AS w1,
            now()::timestamp without time zone AS w2
           FROM dg_full.meta_scheduler_plan p
          WHERE 1 = 1 AND p.plan_ >= (now()::date - '10 days'::interval) AND p.plan_ <= now()::timestamp without time zone AND p.schema_src_id ~~ 's_grnplm_as_cib_gm%'::text
          GROUP BY p.plan_dt, p.schema_src_id
        ), tbl_red AS (
         SELECT pf.schema_src_id,
            max(pf.now_) AS now_,
            count(DISTINCT
                CASE
                    WHEN pf.ready_str = 'red'::text AND pf.node_type_cd::text = 'Table'::text AND pf.fl_max_fact_execute = 1 THEN (pf.schema_src_id || '.'::text) || pf.node_src_id
                    ELSE NULL::text
                END) AS red_cnt
           FROM dg_full.vmeta_scheduler_plan_fact pf
          WHERE 1 = 1 AND pf.plan_trg >= now()::date AND pf.plan_trg <= now()::timestamp without time zone AND pf.schema_src_id ~~ 's_grnplm_as_cib_gm%'::text
          GROUP BY pf.schema_src_id
        ), tbl_wf_fact AS (
         SELECT f_1.max_dttm::date AS fact_dt,
            f_1.sch_name AS schema_src_id,
            count(DISTINCT (f_1.sch_name || '||'::text) || f_1.tbl_name) AS fact_wf_ttl_cn
           FROM dg_full.vmeta_execute_fact f_1
          WHERE 1 = 1 AND f_1.max_dttm >= (now()::date - '10 days'::interval) AND f_1.max_dttm <= now()::timestamp without time zone
          GROUP BY f_1.max_dttm::date, f_1.sch_name
        ), tbl_ttl_list AS (
         SELECT d.start_dt,
            pgn.nspname::text AS schema_src_id,
            obj_description(pgn.oid) AS schema_src_descr,
            count(DISTINCT (pgn.nspname::text || '||'::text) || pgc.relname::text) AS all_cn
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
             CROSS JOIN days10 d
          WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
          GROUP BY d.start_dt, pgn.nspname::text, obj_description(pgn.oid)
        ), tbl_tmpl AS (
         SELECT d.start_dt,
            s.screen_category,
            l_1.screen_template_id,
            o.schema_src_id,
            count(DISTINCT (o.schema_src_id::text || '||'::text) || o.table_src_id::text) AS tmpl_cn
           FROM dg_full.vmeta_screen_link l_1
             JOIN dg_full.vmeta_object_ref_table o ON l_1.object_group_id = o.object_group_id
             JOIN dg_full.meta_screen_template_ref_table s ON l_1.screen_template_id = s.screen_template_id
             CROSS JOIN days10 d
          GROUP BY d.start_dt, s.screen_category, l_1.screen_template_id, o.schema_src_id
        ), tbl_fact AS (
         SELECT b.start_dt::date AS start_dt,
            l_1.screen_template_id,
            s.screen_category,
            f_1.schema_src_id,
            count(DISTINCT (f_1.schema_src_id::text || '||'::text) || f_1.table_src_id::text) AS fact_cn
           FROM dg_full.meta_error_event_fact f_1
             JOIN dg_full.meta_batch_fact b ON f_1.batch_id = b.batch_id
             JOIN dg_full.vmeta_screen_link l_1 ON l_1.screen_id = f_1.screen_id
             JOIN dg_full.meta_screen_template_ref_table s ON l_1.screen_template_id = s.screen_template_id
          WHERE 1 = 1 AND f_1.record_identifier::jsonb ?| ARRAY['unit'::text] AND b.start_dt >= (now()::date - '10 days'::interval) AND b.start_dt <= now()::timestamp without time zone
          GROUP BY b.start_dt::date, l_1.screen_template_id, s.screen_category, f_1.schema_src_id
        ), tbl_ttl_tmpl AS (
         SELECT d.start_dt,
            o.schema_src_id,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id = ANY (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (o.schema_src_id::text || '||'::text) || o.table_src_id::text
                    ELSE NULL::text
                END) AS tmpl_ttl_de_cn,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id <> ALL (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (o.schema_src_id::text || '||'::text) || o.table_src_id::text
                    ELSE NULL::text
                END) AS tmpl_ttl_da_cn
           FROM dg_full.vmeta_screen_link l_1
             JOIN dg_full.vmeta_object_ref_table o ON l_1.object_group_id = o.object_group_id
             CROSS JOIN days10 d
          GROUP BY d.start_dt, o.schema_src_id
        ), tbl_ttl_fact AS (
         SELECT b.start_dt::date AS start_dt,
            f_1.schema_src_id,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id = ANY (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (f_1.schema_src_id::text || '||'::text) || f_1.table_src_id::text
                    ELSE NULL::text
                END) AS fact_ttl_de_cn,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id <> ALL (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (f_1.schema_src_id::text || '||'::text) || f_1.table_src_id::text
                    ELSE NULL::text
                END) AS fact_ttl_da_cn
           FROM dg_full.meta_error_event_fact f_1
             JOIN dg_full.meta_batch_fact b ON f_1.batch_id = b.batch_id
             JOIN dg_full.vmeta_screen_link l_1 ON f_1.screen_id = l_1.screen_id
          WHERE 1 = 1 AND f_1.record_identifier::jsonb ?| ARRAY['unit'::text] AND b.start_dt >= (now()::date - '10 days'::interval) AND b.start_dt <= now()::timestamp without time zone
          GROUP BY b.start_dt::date, f_1.schema_src_id
        )
 SELECT l.schema_src_id,
    l.schema_src_descr,
    l.all_cn,
    COALESCE(t.tmpl_cn, 0::bigint) AS tmpl_cn,
    COALESCE(f.fact_cn, 0::bigint) AS fact_cn,
    COALESCE(l.start_dt, now()::date) AS start_dt,
    COALESCE(t.screen_template_id, f.screen_template_id) AS screen_template_id,
    COALESCE(t.screen_category, f.screen_category) AS screen_category,
    COALESCE(ttt.tmpl_ttl_de_cn, 0::bigint) AS tmpl_ttl_cn,
    COALESCE(ftt.fact_ttl_de_cn, 0::bigint) AS fact_ttl_cn,
    COALESCE(ttt.tmpl_ttl_da_cn, 0::bigint) AS tmpl_ttl_da_cn,
    COALESCE(ftt.fact_ttl_da_cn, 0::bigint) AS fact_ttl_da_cn,
    COALESCE(stt.plan_ttl_cn, 0::bigint) AS plan_ttl_cn,
    COALESCE(wftt.fact_wf_ttl_cn, 0::bigint) AS fact_wf_ttl_cn,
    COALESCE(stt.plan_kkd_ttl_cn, 0::bigint) AS plan_kkd_ttl_cn,
    COALESCE(stt.fact_kkd_ttl_cn, 0::bigint) AS fact_kkd_ttl_cn,
    r.now_ AS pf_now_,
    r.red_cnt
   FROM tbl_ttl_list l
     LEFT JOIN tbl_ttl_tmpl ttt ON l.schema_src_id = ttt.schema_src_id::text AND COALESCE(l.start_dt, now()::date) = COALESCE(ttt.start_dt, now()::date)
     LEFT JOIN tbl_ttl_fact ftt ON l.schema_src_id = ftt.schema_src_id::text AND COALESCE(l.start_dt, now()::date) = COALESCE(ftt.start_dt, now()::date)
     LEFT JOIN tbl_sched stt ON l.schema_src_id = stt.schema_src_id AND COALESCE(l.start_dt, now()::date) = COALESCE(stt.plan_dt, now()::date)
     LEFT JOIN tbl_wf_fact wftt ON l.schema_src_id = wftt.schema_src_id AND COALESCE(l.start_dt, now()::date) = COALESCE(wftt.fact_dt, now()::date)
     LEFT JOIN tbl_tmpl t ON l.schema_src_id = t.schema_src_id::text AND COALESCE(l.start_dt, now()::date) = COALESCE(t.start_dt, now()::date)
     LEFT JOIN tbl_fact f ON l.schema_src_id = f.schema_src_id::text AND t.screen_template_id = f.screen_template_id AND COALESCE(l.start_dt, now()::date) = COALESCE(f.start_dt, now()::date)
     LEFT JOIN tbl_red r ON l.schema_src_id = r.schema_src_id;


-- dg_full.vmeta_dq_statistic_lg source

CREATE OR REPLACE VIEW dg_full.vmeta_dq_statistic_lg
AS WITH days10 AS (
         SELECT ts_report.ts_report::date AS start_dt
           FROM generate_series((now()::date - '10 days'::interval)::date::timestamp with time zone, now()::date::timestamp with time zone, '1 day'::interval) ts_report(ts_report)
        ), tbl_sched AS (
         SELECT p.plan_dt,
            p.schema_src_id,
            count(DISTINCT (p.schema_src_id || '||'::text) || p.node_src_id) AS plan_ttl_cn,
            count(DISTINCT
                CASE
                    WHEN ((p.schema_src_id, p.node_src_id) IN ( SELECT o.schema_src_id,
                        o.table_src_id
                       FROM dg_full.vmeta_object_ref_table o
                      GROUP BY o.schema_src_id, o.table_src_id)) THEN (p.schema_src_id || '||'::text) || p.node_src_id
                    ELSE NULL::text
                END) AS plan_kkd_ttl_cn,
            count(DISTINCT
                CASE
                    WHEN ((p.plan_dt, p.schema_src_id, p.node_src_id) IN ( SELECT f_1.load_dttm::date AS load_dttm,
                        f_1.schema_src_id,
                        f_1.table_src_id
                       FROM dg_full.meta_error_event_fact f_1
                      GROUP BY f_1.load_dttm::date, f_1.schema_src_id, f_1.table_src_id)) THEN (p.schema_src_id || '||'::text) || p.node_src_id
                    ELSE NULL::text
                END) AS fact_kkd_ttl_cn,
            now()::date::timestamp without time zone AS w1,
            now()::timestamp without time zone AS w2
           FROM dg_full.meta_scheduler_plan p
          WHERE 1 = 1 AND p.plan_ >= (now()::date - '10 days'::interval) AND p.plan_ <= now()::timestamp without time zone AND p.schema_src_id ~~ 's_grnplm_as_cib_gm%'::text
          GROUP BY p.plan_dt, p.schema_src_id
        ), tbl_red AS (
         SELECT pf.schema_src_id,
            max(pf.now_) AS now_,
            count(DISTINCT
                CASE
                    WHEN pf.ready_str = 'red'::text AND pf.node_type_cd::text = 'Table'::text AND pf.fl_max_fact_execute = 1 THEN (pf.schema_src_id || '.'::text) || pf.node_src_id
                    ELSE NULL::text
                END) AS red_cnt
           FROM dg_full.vmeta_scheduler_plan_fact pf
          WHERE 1 = 1 AND pf.plan_trg >= now()::date AND pf.plan_trg <= now()::timestamp without time zone AND pf.schema_src_id ~~ 's_grnplm_as_cib_gm%'::text
          GROUP BY pf.schema_src_id
        ), tbl_wf_fact AS (
         SELECT f_1.max_dttm::date AS fact_dt,
            f_1.sch_name AS schema_src_id,
            count(DISTINCT (f_1.sch_name || '||'::text) || f_1.tbl_name) AS fact_wf_ttl_cn
           FROM dg_full.vmeta_execute_fact f_1
          WHERE 1 = 1 AND f_1.max_dttm >= (now()::date - '10 days'::interval) AND f_1.max_dttm <= now()::timestamp without time zone
          GROUP BY f_1.max_dttm::date, f_1.sch_name
        ), tbl_ttl_list AS (
         SELECT d.start_dt,
            pgn.nspname::text AS schema_src_id,
            obj_description(pgn.oid) AS schema_src_descr,
            count(DISTINCT (pgn.nspname::text || '||'::text) || pgc.relname::text) AS all_cn
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
             CROSS JOIN days10 d
          WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
          GROUP BY d.start_dt, pgn.nspname::text, obj_description(pgn.oid)
        ), tbl_tmpl AS (
         SELECT d.start_dt,
            s.screen_category,
            l_1.screen_template_id,
            o.schema_src_id,
            count(DISTINCT (o.schema_src_id::text || '||'::text) || o.table_src_id::text) AS tmpl_cn
           FROM s_grnplm_as_cib_gm_dg.vmeta_screen_link l_1
             JOIN s_grnplm_as_cib_gm_dg.vmeta_object_ref_table o ON l_1.object_group_id = o.object_group_id
             JOIN s_grnplm_as_cib_gm_dg.meta_screen_template_ref_table s ON l_1.screen_template_id = s.screen_template_id
             CROSS JOIN days10 d
          GROUP BY d.start_dt, s.screen_category, l_1.screen_template_id, o.schema_src_id
        ), tbl_fact AS (
         SELECT b.start_dt::date AS start_dt,
            l_1.screen_template_id,
            s.screen_category,
            f_1.schema_src_id,
            count(DISTINCT (f_1.schema_src_id::text || '||'::text) || f_1.table_src_id::text) AS fact_cn
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f_1
             JOIN s_grnplm_as_cib_gm_dg.meta_batch_fact b ON f_1.batch_id = b.batch_id
             JOIN s_grnplm_as_cib_gm_dg.vmeta_screen_link l_1 ON l_1.screen_id = f_1.screen_id
             JOIN s_grnplm_as_cib_gm_dg.meta_screen_template_ref_table s ON l_1.screen_template_id = s.screen_template_id
          WHERE 1 = 1 AND f_1.record_identifier::jsonb ?| ARRAY['unit'::text] AND b.start_dt >= (now()::date - '10 days'::interval) AND b.start_dt <= now()::timestamp without time zone
          GROUP BY b.start_dt::date, l_1.screen_template_id, s.screen_category, f_1.schema_src_id
        ), tbl_ttl_tmpl AS (
         SELECT d.start_dt,
            o.schema_src_id,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id = ANY (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (o.schema_src_id::text || '||'::text) || o.table_src_id::text
                    ELSE NULL::text
                END) AS tmpl_ttl_de_cn,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id <> ALL (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (o.schema_src_id::text || '||'::text) || o.table_src_id::text
                    ELSE NULL::text
                END) AS tmpl_ttl_da_cn
           FROM s_grnplm_as_cib_gm_dg.vmeta_screen_link l_1
             JOIN s_grnplm_as_cib_gm_dg.vmeta_object_ref_table o ON l_1.object_group_id = o.object_group_id
             CROSS JOIN days10 d
          GROUP BY d.start_dt, o.schema_src_id
        ), tbl_ttl_fact AS (
         SELECT b.start_dt::date AS start_dt,
            f_1.schema_src_id,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id = ANY (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (f_1.schema_src_id::text || '||'::text) || f_1.table_src_id::text
                    ELSE NULL::text
                END) AS fact_ttl_de_cn,
            count(DISTINCT
                CASE
                    WHEN l_1.screen_template_id <> ALL (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]) THEN (f_1.schema_src_id::text || '||'::text) || f_1.table_src_id::text
                    ELSE NULL::text
                END) AS fact_ttl_da_cn
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f_1
             JOIN s_grnplm_as_cib_gm_dg.meta_batch_fact b ON f_1.batch_id = b.batch_id
             JOIN s_grnplm_as_cib_gm_dg.vmeta_screen_link l_1 ON f_1.screen_id = l_1.screen_id
          WHERE 1 = 1 AND f_1.record_identifier::jsonb ?| ARRAY['unit'::text] AND b.start_dt >= (now()::date - '10 days'::interval) AND b.start_dt <= now()::timestamp without time zone
          GROUP BY b.start_dt::date, f_1.schema_src_id
        )
 SELECT l.schema_src_id,
    l.schema_src_descr,
    l.all_cn,
    COALESCE(t.tmpl_cn, 0::bigint) AS tmpl_cn,
    COALESCE(f.fact_cn, 0::bigint) AS fact_cn,
    COALESCE(l.start_dt, now()::date) AS start_dt,
    COALESCE(t.screen_template_id, f.screen_template_id) AS screen_template_id,
    COALESCE(t.screen_category, f.screen_category) AS screen_category,
    COALESCE(ttt.tmpl_ttl_de_cn, 0::bigint) AS tmpl_ttl_cn,
    COALESCE(ftt.fact_ttl_de_cn, 0::bigint) AS fact_ttl_cn,
    COALESCE(ttt.tmpl_ttl_da_cn, 0::bigint) AS tmpl_ttl_da_cn,
    COALESCE(ftt.fact_ttl_da_cn, 0::bigint) AS fact_ttl_da_cn,
    COALESCE(stt.plan_ttl_cn, 0::bigint) AS plan_ttl_cn,
    COALESCE(wftt.fact_wf_ttl_cn, 0::bigint) AS fact_wf_ttl_cn,
    COALESCE(stt.plan_kkd_ttl_cn, 0::bigint) AS plan_kkd_ttl_cn,
    COALESCE(stt.fact_kkd_ttl_cn, 0::bigint) AS fact_kkd_ttl_cn,
    r.now_ AS pf_now_,
    r.red_cnt
   FROM tbl_ttl_list l
     LEFT JOIN tbl_ttl_tmpl ttt ON l.schema_src_id = ttt.schema_src_id::text AND COALESCE(l.start_dt, now()::date) = COALESCE(ttt.start_dt, now()::date)
     LEFT JOIN tbl_ttl_fact ftt ON l.schema_src_id = ftt.schema_src_id::text AND COALESCE(l.start_dt, now()::date) = COALESCE(ftt.start_dt, now()::date)
     LEFT JOIN tbl_sched stt ON l.schema_src_id = stt.schema_src_id AND COALESCE(l.start_dt, now()::date) = COALESCE(stt.plan_dt, now()::date)
     LEFT JOIN tbl_wf_fact wftt ON l.schema_src_id = wftt.schema_src_id AND COALESCE(l.start_dt, now()::date) = COALESCE(wftt.fact_dt, now()::date)
     LEFT JOIN tbl_tmpl t ON l.schema_src_id = t.schema_src_id::text AND COALESCE(l.start_dt, now()::date) = COALESCE(t.start_dt, now()::date)
     LEFT JOIN tbl_fact f ON l.schema_src_id = f.schema_src_id::text AND t.screen_template_id = f.screen_template_id AND COALESCE(l.start_dt, now()::date) = COALESCE(f.start_dt, now()::date)
     LEFT JOIN tbl_red r ON l.schema_src_id = r.schema_src_id;


-- dg_full.vmeta_edge_link_views_rel source

CREATE OR REPLACE VIEW dg_full.vmeta_edge_link_views_rel
AS WITH temp_bb AS (
         SELECT now() AS load_dttm,
            'GP'::text AS src_cd,
            '-1'::integer AS wf_load_id,
            replace(ns_src.nspname::text, '"'::text, ''::text) AS src_schema_src_id,
            t.relname AS src_node_src_id,
            ns_tgt.nspname AS target_schema_src_id,
            replace(v.relname::text, '"'::text, ''::text) AS target_node_src_id,
            2 AS edge_type_src_id,
            1 AS weight,
            1 AS order_by,
                CASE
                    WHEN pp.property_val = '1'::text THEN true
                    ELSE false
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
                END AS src_node_type_cd,
            v.relowner,
            NULL::name AS rolname
           FROM pg_depend d
             JOIN pg_rewrite r ON r.oid = d.objid
             JOIN pg_class v ON v.oid = r.ev_class
             JOIN pg_namespace ns_tgt ON ns_tgt.oid = v.relnamespace
             JOIN pg_class t ON t.oid = d.refobjid
             JOIN pg_namespace ns_src ON ns_src.oid = t.relnamespace
             LEFT JOIN dg_full.vmeta_property_hsat pp ON pp.object_src_id::name = t.relname AND pp.schema_src_id::name = ns_src.nspname AND pp.property_type_src_id = 6
          WHERE 1 = 1 AND (v.relkind = ANY (ARRAY['p'::"char", 't'::"char", 'r'::"char", 'v'::"char", 'm'::"char", 'f'::"char"])) AND d.classid = 'pg_rewrite'::regclass::oid AND (d.refclassid = 'pg_class'::regclass::oid OR d.refclassid = 'pg_proc'::regclass::oid) AND NOT v.oid = d.refobjid AND ns_src.nspname <> 'pg_catalog'::name AND ns_tgt.nspname <> 'pg_catalog'::name
          GROUP BY now(), 'GP'::text, '-1'::integer, replace(ns_src.nspname::text, '"'::text, ''::text), t.relname, ns_tgt.nspname, replace(v.relname::text, '"'::text, ''::text), 2::integer, 1::integer,
                CASE
                    WHEN pp.property_val = '1'::text THEN true
                    ELSE false
                END,
                CASE
                    WHEN v.relkind = 'v'::"char" THEN 'View'::text
                    WHEN v.relkind = 'm'::"char" THEN 'View'::text
                    WHEN v.relkind = 'p'::"char" THEN 'Table'::text
                    WHEN v.relkind = 'r'::"char" THEN 'Table'::text
                    WHEN v.relkind = 't'::"char" THEN 'Table'::text
                    WHEN v.relkind = 'f'::"char" THEN 'Function'::text
                    ELSE v.relkind::text
                END,
                CASE
                    WHEN t.relkind = ANY (ARRAY['v'::"char", 'm'::"char"]) THEN 'View'::text
                    WHEN v.relkind = ANY (ARRAY['p'::"char", 'r'::"char", 't'::"char"]) THEN 'Table'::text
                    WHEN t.relkind = ANY (ARRAY['p'::"char", 'r'::"char", 't'::"char"]) THEN 'Table'::text
                    WHEN t.relkind = 'f'::"char" THEN 'Function'::text
                    ELSE t.relkind::text
                END, v.relowner
        )
 SELECT DISTINCT - 1::bigint AS edge_id,
    bb.load_dttm,
    bb.src_cd,
    bb.wf_load_id,
    '1900-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    bb.src_schema_src_id::name AS src_schema_src_id,
    bb.src_node_src_id,
    bb.target_schema_src_id,
    bb.target_node_src_id::name AS target_node_src_id,
    bb.edge_type_src_id,
    bb.weight,
    bb.order_by,
    true AS is_active,
    ee.edge_type_cd,
    (bb.src_schema_src_id || '.'::text) || bb.src_node_src_id::text AS src_node_id,
    (bb.target_schema_src_id::text || '.'::text) || bb.target_node_src_id AS target_node_id,
    bb.tgt_node_type_cd,
    bb.src_node_type_cd,
    bb.relowner,
    bb.rolname
   FROM temp_bb bb
     JOIN dg_full.meta_edge_type_ref_table ee ON bb.edge_type_src_id = ee.edge_type_src_id
  GROUP BY - 1::bigint, bb.load_dttm, bb.src_cd, bb.wf_load_id, '1900-01-01 00:00:00'::timestamp without time zone, '2999-12-31 00:00:00'::timestamp without time zone, now(), bb.src_schema_src_id::name, bb.src_node_src_id, bb.target_schema_src_id, bb.target_node_src_id::name, bb.edge_type_src_id, bb.weight, bb.order_by,
        CASE
            WHEN bb.src_node_src_id ~~ '%save_step_to_logs%'::text OR bb.target_node_src_id ~~ '%save_step_to_logs%'::text THEN false
            ELSE bb.is_active
        END, ee.edge_type_cd, (bb.src_schema_src_id || '.'::text) || bb.src_node_src_id::text, (bb.target_schema_src_id::text || '.'::text) || bb.target_node_src_id, bb.tgt_node_type_cd, bb.src_node_type_cd, bb.relowner, bb.rolname;


-- dg_full.vmeta_error_event_fact_cred source

CREATE OR REPLACE VIEW dg_full.vmeta_error_event_fact_cred
AS WITH pull_error AS (
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND msl.screen_template_id = 77
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND msl.screen_template_id = 78
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND msl.screen_template_id = 79
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND msl.screen_template_id = 80
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND msl.screen_template_id = 81 AND (((meef.record_identifier ->> 'product'::text) = 'Банковские гарантии'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'balance_provisions_ras'::text, 'llp_charge_m'::text, 'llp_charge_q'::text, 'llp_charge_ye'::text, 'llp_charge_ras_m'::text, 'llp_charge_ras_q'::text, 'llp_charge_ras_ye'::text, 'previous_net_revs_ye'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'rwa_eop'::text, 'lgdabs'::text, 'elabs'::text]))) OR ((meef.record_identifier ->> 'product'::text) = 'Договор о предоставлении банковской гарантии'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['undrawn_amount_llp_m'::text, 'undrawn_amount_llp_q'::text, 'undrawn_amount_llp_ye'::text, 'undrawn_amount_llp_ras_m'::text, 'undrawn_amount_llp_ras_q'::text, 'undrawn_amount_llp_ras_ye'::text]))) OR ((meef.record_identifier ->> 'product'::text) = 'Кредит'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'balance_provisions_ras'::text, 'llp_charge_m'::text, 'llp_charge_q'::text, 'llp_charge_ye'::text, 'llp_charge_ras_m'::text, 'llp_charge_ras_q'::text, 'llp_charge_ras_ye'::text, 'previous_net_revs_ye'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'rwa_eop'::text, 'lgdabs'::text, 'elabs'::text, 'undrawn_amount'::text, 'undrawn_amount_provisions'::text, 'undrawn_amount_provisions_ras'::text, 'undrawn_amount_llp_m'::text, 'undrawn_amount_llp_q'::text, 'undrawn_amount_llp_ye'::text, 'undrawn_amount_llp_ras_m'::text, 'undrawn_amount_llp_ras_q'::text, 'undrawn_amount_llp_ras_ye'::text, 'efect_of_loss_of_interest_income_during_restructuring'::text, 'efect_of_loss_of_interest_income_on_early_repayment'::text, 'credit_commissions'::text, 'customer_fee_on_early_repayment'::text, 'funding_available_limit'::text, 'interest_income_as_nominal_rate'::text, 'adjustments_to_bring_up_the_effective_rate'::text]))) OR ((meef.record_identifier ->> 'product'::text) = 'Облигации'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'previous_net_revs_ye'::text, 'llp_charge_m'::text, 'llp_charge_q'::text, 'llp_charge_ye'::text]))) OR (((meef.record_identifier ->> 'product'::text) = ANY (ARRAY['Repo'::text, 'Prepay'::text])) AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'previous_net_revs_ye'::text]))))
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND msl.screen_template_id = 82
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND msl.screen_template_id = 83 AND (meef.record_identifier ->> 'unit'::text) IS NULL AND (((meef.record_identifier ->> 'product'::text) = 'Банковские гарантии'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'previous_net_revs_ye'::text, 'rwa_eop'::text, 'balance_provisions'::text, 'balance_provisions_ras'::text]))) OR ((meef.record_identifier ->> 'product'::text) = 'Договор о предоставлении банковской гарантии'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['undrawn_amount'::text, 'undrawn_amount_llp_m'::text, 'undrawn_amount_llp_ras_m'::text]))) OR ((meef.record_identifier ->> 'product'::text) = 'Кредит'::text AND ((meef.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'rwa_eop'::text, 'previous_net_revs_ye'::text, 'undrawn_amount'::text])))) AND (((meef.record_identifier ->> 'reason_type'::text) = '%'::text AND ((meef.record_identifier ->> 'reason_value'::text)::numeric)::double precision < meef.record_error) OR ((meef.record_identifier ->> 'reason_type'::text) <> '%'::text AND ((meef.record_identifier ->> 'reason_value'::text)::numeric)::double precision <> meef.record_error))
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND msl.screen_template_id = 84 AND (meef.record_identifier ->> 'unit'::text) IS NULL
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND msl.screen_template_id = 85 AND (meef.record_identifier ->> 'unit'::text) IS NULL
        UNION ALL
         SELECT meef.batch_id,
            "substring"(b.batch_params, strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26, length(b.batch_params) - (strpos(b.batch_params, 'p_tbl_rstri_wf_load_id = "'::text) + 26) - 1) AS params_wf_load_id,
            b.wf_load_id,
            meef.record_identifier ->> 'reporting_date'::text AS reporting_date,
            meef.record_identifier ->> 'product'::text AS product,
            meef.record_identifier ->> 'attr'::text AS attr,
            meef.record_identifier ->> 'segments'::text AS segments,
            meef.record_identifier ->> 'pre_product'::text AS pre_product,
            meef.record_identifier ->> 'reason_value'::text AS reason_value,
            meef.record_identifier ->> 'reason_type'::text AS reason_type,
            meef.record_identifier ->> 'orig'::text AS orig,
            meef.record_identifier ->> 'calc'::text AS calc,
            meef.record_identifier ->> 'prev'::text AS prev,
            meef.record_identifier ->> 'cn_prev'::text AS cn_prev,
            meef.record_identifier ->> 'curr'::text AS curr,
            meef.record_identifier ->> 'cn_curr'::text AS cn_curr,
            meef.record_identifier ->> 'diff'::text AS diff,
            meef.value,
            meef.record_error,
            msl.screen_template_id,
            msl.object_group_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_batch_fact b ON meef.batch_id = b.batch_id
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE 1 = 1 AND msl.screen_template_id = 86 AND (meef.record_identifier ->> 'unit'::text) IS NULL
        )
 SELECT err.batch_id,
    err.reporting_date,
    err.product,
    err.attr,
    err.segments,
    err.pre_product,
    err.reason_value,
    err.reason_type,
    err.orig,
    err.calc,
    err.prev,
    err.cn_prev,
    err.curr,
    err.cn_curr,
    err.diff,
    err.value,
    err.record_error,
    strt.descr,
    err.screen_template_id,
    err.object_group_id,
    err.params_wf_load_id,
    err.wf_load_id,
        CASE
            WHEN err.screen_template_id = 81 AND err.record_error = 100::double precision THEN 'red'::text
            WHEN (err.screen_template_id = ANY (ARRAY[77, 80, 82, 83, 85, 86])) AND err.record_error > 0::double precision THEN 'red'::text
            ELSE 'green'::text
        END AS fl_exception
   FROM pull_error err
     LEFT JOIN dg_full.meta_screen_template_ref_table strt ON strt.screen_template_id = err.screen_template_id
  WHERE 1 = 1;


-- dg_full.vmeta_error_event_stat source

CREATE OR REPLACE VIEW dg_full.vmeta_error_event_stat
AS SELECT tt1.schema_src_id,
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
   FROM ( SELECT DISTINCT m.schema_src_id,
            m.table_src_id,
            m.screen_id,
            m.metric,
            m.wf_load_id,
            m.record_identifier::jsonb ->> 'unit'::text AS unit,
            max(m.wf_load_id) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text) AS max_wf_load_id,
            count(*) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text) AS str_cnt,
            min(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text) AS min_rec_error,
            max(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text) AS max_rec_error,
            avg(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text) AS avg_rec_error,
            stddev(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text) AS stddev_rec_error,
            avg(m.record_error) OVER (PARTITION BY m.screen_id, m.schema_src_id, m.table_src_id, m.record_identifier::jsonb ->> 'unit'::text ORDER BY m.load_dttm ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS avg_moving_rec_error
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact m
          WHERE 1 = 1 AND m.record_identifier::jsonb ?| ARRAY['unit'::text]) tt1
  WHERE 1 = 1 AND tt1.wf_load_id = tt1.max_wf_load_id;


-- dg_full.vmeta_error_fact_cred source

CREATE OR REPLACE VIEW dg_full.vmeta_error_fact_cred
AS WITH pull_error AS (
         SELECT msl.screen_template_id,
            obj.table_src_id
           FROM dg_full.meta_screen_link msl
             JOIN dg_full.meta_object_ref_table obj ON obj.object_group_id = msl.object_group_id
          WHERE obj.table_src_id::text = 'hfact_tib_cred'::text
          GROUP BY msl.screen_template_id, obj.table_src_id
        ), pull_error_fact AS (
         SELECT meef.batch_id,
            max(meef.batch_id) OVER (PARTITION BY (meef.record_identifier ->> 'reporting_date'::text)::date) AS m_batch_id,
            (meef.record_identifier ->> 'reporting_date'::text)::date AS reporting_date,
            meef.record_identifier,
            meef.value,
            meef.record_error,
            msl.screen_template_id
           FROM dg_full.meta_error_event_fact meef
             JOIN dg_full.meta_screen_link msl ON meef.screen_id = msl.screen_id AND msl.eff_to_dt = '2999-12-31'::date
          WHERE (meef.record_identifier ->> 'unit'::text) IS NULL AND (EXISTS ( SELECT 1
                   FROM pull_error perr
                  WHERE perr.screen_template_id = msl.screen_template_id AND perr.table_src_id::text = meef.table_src_id::text))
        ), error_fact AS (
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            NULL::text AS curr_or_orig,
            NULL::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 77
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            pull_error_fact.record_identifier ->> 'curr'::text AS curr_or_orig,
            pull_error_fact.record_identifier ->> 'prev'::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.reporting_date > last_day(date_trunc('year'::text, pull_error_fact.reporting_date::timestamp with time zone)) AND pull_error_fact.screen_template_id = 78
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            COALESCE(pull_error_fact.record_identifier ->> 'product'::text, pull_error_fact.record_identifier ->> 'pre_product'::text) AS product,
            NULL::text AS attr,
            pull_error_fact.record_identifier ->> 'curr'::text AS curr_or_orig,
            NULL::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 80
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            NULL::text AS curr_or_orig,
            NULL::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 81 AND pull_error_fact.record_error = 100::double precision AND (((pull_error_fact.record_identifier ->> 'product'::text) = 'Банковские гарантии'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'balance_provisions_ras'::text, 'llp_charge_m'::text, 'llp_charge_q'::text, 'llp_charge_ye'::text, 'llp_charge_ras_m'::text, 'llp_charge_ras_q'::text, 'llp_charge_ras_ye'::text, 'previous_net_revs_ye'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'rwa_eop'::text, 'lgdabs'::text, 'elabs'::text]))) OR ((pull_error_fact.record_identifier ->> 'product'::text) = 'Договор о предоставлении банковской гарантии'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['undrawn_amount_llp_m'::text, 'undrawn_amount_llp_q'::text, 'undrawn_amount_llp_ye'::text, 'undrawn_amount_llp_ras_m'::text, 'undrawn_amount_llp_ras_q'::text, 'undrawn_amount_llp_ras_ye'::text]))) OR ((pull_error_fact.record_identifier ->> 'product'::text) = 'Кредит'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'balance_provisions_ras'::text, 'llp_charge_m'::text, 'llp_charge_q'::text, 'llp_charge_ye'::text, 'llp_charge_ras_m'::text, 'llp_charge_ras_q'::text, 'llp_charge_ras_ye'::text, 'previous_net_revs_ye'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'rwa_eop'::text, 'lgdabs'::text, 'elabs'::text, 'undrawn_amount'::text, 'undrawn_amount_provisions'::text, 'undrawn_amount_provisions_ras'::text, 'undrawn_amount_llp_m'::text, 'undrawn_amount_llp_q'::text, 'undrawn_amount_llp_ye'::text, 'undrawn_amount_llp_ras_m'::text, 'undrawn_amount_llp_ras_q'::text, 'undrawn_amount_llp_ras_ye'::text, 'efect_of_loss_of_interest_income_during_restructuring'::text, 'efect_of_loss_of_interest_income_on_early_repayment'::text, 'credit_commissions'::text, 'customer_fee_on_early_repayment'::text, 'funding_available_limit'::text, 'interest_income_as_nominal_rate'::text, 'adjustments_to_bring_up_the_effective_rate'::text]))) OR ((pull_error_fact.record_identifier ->> 'product'::text) = 'Облигации'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'previous_net_revs_ye'::text, 'llp_charge_m'::text, 'llp_charge_q'::text, 'llp_charge_ye'::text]))) OR (((pull_error_fact.record_identifier ->> 'product'::text) = ANY (ARRAY['Repo'::text, 'Prepay'::text])) AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'net_revs_q'::text, 'net_revs_ye'::text, 'previous_net_revs_ye'::text]))))
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            pull_error_fact.record_identifier ->> 'orig'::text AS curr_or_orig,
            pull_error_fact.record_identifier ->> 'calc'::text AS prev_or_calc,
            (pull_error_fact.record_identifier ->> 'diff'::text)::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 82
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            pull_error_fact.record_identifier ->> 'curr'::text AS curr_or_orig,
            pull_error_fact.record_identifier ->> 'prev'::text AS prev_or_calc,
            (pull_error_fact.record_identifier ->> 'diff'::text)::numeric AS diff,
            pull_error_fact.record_error,
            pull_error_fact.record_identifier ->> 'reason_type'::text AS reason_type,
            (pull_error_fact.record_identifier ->> 'reason_value'::text)::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 83 AND (((pull_error_fact.record_identifier ->> 'product'::text) = 'Банковские гарантии'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'previous_net_revs_ye'::text, 'rwa_eop'::text, 'balance_provisions'::text, 'balance_provisions_ras'::text]))) OR ((pull_error_fact.record_identifier ->> 'product'::text) = 'Договор о предоставлении банковской гарантии'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['undrawn_amount'::text, 'undrawn_amount_provisions'::text, 'undrawn_amount_provisions_ras'::text]))) OR ((pull_error_fact.record_identifier ->> 'product'::text) = 'Кредит'::text AND ((pull_error_fact.record_identifier ->> 'attr'::text) = ANY (ARRAY['balance_eop'::text, 'balance_avg_m'::text, 'balance_avg_q'::text, 'balance_avg_ye'::text, 'balance_provisions'::text, 'rwa_eop'::text, 'previous_net_revs_ye'::text, 'undrawn_amount'::text])))) AND (((pull_error_fact.record_identifier ->> 'reason_type'::text) = '%'::text AND ((pull_error_fact.record_identifier ->> 'reason_value'::text)::numeric) <= pull_error_fact.record_error::numeric) OR ((pull_error_fact.record_identifier ->> 'reason_type'::text) <> '%'::text AND abs(abs((pull_error_fact.record_identifier ->> 'reason_value'::text)::numeric) - abs((pull_error_fact.record_identifier ->> 'diff'::text)::numeric)) > 1::numeric))
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            NULL::text AS attr,
            NULL::text AS curr_or_orig,
            NULL::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 84
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            NULL::text AS curr_or_orig,
            NULL::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 85
        UNION ALL
         SELECT pull_error_fact.reporting_date,
            pull_error_fact.record_identifier ->> 'product'::text AS product,
            pull_error_fact.record_identifier ->> 'attr'::text AS attr,
            NULL::text AS curr_or_orig,
            NULL::text AS prev_or_calc,
            NULL::numeric AS diff,
            pull_error_fact.record_error,
            NULL::text AS reason_type,
            NULL::numeric AS reason_value,
            pull_error_fact.screen_template_id
           FROM pull_error_fact
          WHERE pull_error_fact.batch_id = pull_error_fact.m_batch_id AND pull_error_fact.screen_template_id = 86
        )
 SELECT err.reporting_date,
    err.product,
    err.attr,
    err.curr_or_orig,
    err.prev_or_calc,
    err.diff,
    err.record_error,
    err.reason_type,
    err.reason_value,
    strt.descr,
    err.screen_template_id,
        CASE
            WHEN err.screen_template_id = 81 AND err.record_error = 100::double precision THEN 'red'::text
            WHEN (err.screen_template_id = ANY (ARRAY[77, 80, 82, 83, 85, 86])) AND err.record_error > 0::double precision THEN 'red'::text
            ELSE 'green'::text
        END AS fl_exception
   FROM error_fact err
     LEFT JOIN dg_full.meta_screen_template_ref_table strt ON strt.screen_template_id = err.screen_template_id;


-- dg_full.vmeta_exception_action_ref_table source

CREATE OR REPLACE VIEW dg_full.vmeta_exception_action_ref_table
AS WITH temp_d AS (
         SELECT meta_exception_action_ref_table.exception_action_id,
            meta_exception_action_ref_table.exception_action_name,
            meta_exception_action_ref_table.load_dttm,
            meta_exception_action_ref_table.wf_load_id,
            meta_exception_action_ref_table.src_cd,
            meta_exception_action_ref_table.exception_action_descr,
            meta_exception_action_ref_table.exception_group_id,
            meta_exception_action_ref_table.prc_from,
            COALESCE(meta_exception_action_ref_table.prc_to, 9999::real) AS prc_to,
                CASE
                    WHEN (meta_exception_action_ref_table.exception_action_id <> ALL (ARRAY[14, 25, 15, 24])) AND COALESCE(lead(meta_exception_action_ref_table.prc_from) OVER (PARTITION BY meta_exception_action_ref_table.exception_group_id ORDER BY meta_exception_action_ref_table.exception_group_id, meta_exception_action_ref_table.exception_action_id), meta_exception_action_ref_table.prc_from) < COALESCE(lag(meta_exception_action_ref_table.prc_from) OVER (PARTITION BY meta_exception_action_ref_table.exception_group_id ORDER BY meta_exception_action_ref_table.exception_group_id, meta_exception_action_ref_table.exception_action_id), COALESCE(meta_exception_action_ref_table.prc_to, 9999::real)) THEN 'Red to Green'::text
                    WHEN (meta_exception_action_ref_table.exception_action_id <> ALL (ARRAY[14, 25, 15, 24])) AND COALESCE(lead(meta_exception_action_ref_table.prc_from) OVER (PARTITION BY meta_exception_action_ref_table.exception_group_id ORDER BY meta_exception_action_ref_table.exception_group_id, meta_exception_action_ref_table.exception_action_id), meta_exception_action_ref_table.prc_from) >= COALESCE(lag(meta_exception_action_ref_table.prc_from) OVER (PARTITION BY meta_exception_action_ref_table.exception_group_id ORDER BY meta_exception_action_ref_table.exception_group_id, meta_exception_action_ref_table.exception_action_id), COALESCE(meta_exception_action_ref_table.prc_to, 9999::real)) THEN 'Green to Red'::text
                    WHEN meta_exception_action_ref_table.exception_action_id = ANY (ARRAY[14, 25]) THEN 'Green'::text
                    WHEN meta_exception_action_ref_table.exception_action_id = ANY (ARRAY[24, 15]) THEN 'Red'::text
                    ELSE 'Gray'::text
                END AS action_gradient
           FROM dg_full.meta_exception_action_ref_table
        ), temp_dd AS (
         SELECT d.exception_action_id,
            d.exception_action_name,
            d.load_dttm,
            d.wf_load_id,
            d.src_cd,
            d.exception_action_descr,
            d.exception_group_id,
            d.prc_from,
            d.prc_to,
            d.action_gradient,
                CASE
                    WHEN d.action_gradient = 'Green to Red'::text THEN rank() OVER (PARTITION BY d.exception_group_id ORDER BY d.prc_to)
                    WHEN d.action_gradient = 'Red to Green'::text THEN rank() OVER (PARTITION BY d.exception_group_id ORDER BY d.prc_to DESC)
                    WHEN d.action_gradient = 'Red'::text THEN 1::bigint
                    ELSE 0::bigint
                END AS interval_rank,
                CASE
                    WHEN d.action_gradient = 'Green to Red'::text THEN max(d.prc_to) OVER (PARTITION BY d.exception_group_id)
                    WHEN d.action_gradient = 'Red to Green'::text THEN min(d.prc_to) OVER (PARTITION BY d.exception_group_id)
                    WHEN d.action_gradient = 'Red'::text THEN d.prc_to
                    ELSE 0::real
                END AS red_interval_prc_to
           FROM temp_d d
        )
 SELECT tt.exception_action_id,
    tt.exception_action_name,
    tt.load_dttm,
    tt.wf_load_id::bigint AS wf_load_id,
    tt.src_cd,
    tt.exception_action_descr,
    tt.exception_group_id,
    tt.prc_from,
    tt.prc_to,
    tt.action_gradient,
    tt.interval_rank,
    tt.red_interval_prc_to,
        CASE
            WHEN tt.prc_to = tt.red_interval_prc_to AND (tt.action_gradient = ANY (ARRAY['Green to Red'::text, 'Red to Green'::text])) THEN 'Red'::text
            WHEN tt.action_gradient = 'Red'::text THEN 'Red'::text
            ELSE NULL::text
        END AS red_flg
   FROM temp_dd tt;


-- dg_full.vmeta_exception_group source

CREATE OR REPLACE VIEW dg_full.vmeta_exception_group
AS SELECT eg.exception_group_id,
    eg.exception_group_name,
    eg.exception_group_descr,
    ea.exception_action_id,
    ea.exception_action_name,
    ea.exception_action_descr,
    ea.prc_from,
    ea.prc_to
   FROM dg_full.meta_exception_group_ref_table eg
     JOIN dg_full.meta_exception_action_ref_table ea ON eg.exception_group_id = ea.exception_group_id;


-- dg_full.vmeta_execute_fact source

CREATE OR REPLACE VIEW dg_full.vmeta_execute_fact
AS WITH fact_ctl_ods AS (
         SELECT m_1.nspname AS sch_name,
            m_1.relname AS tbl_name,
            m_1.started AS max_eff_from_dttm,
            m_1.created_at AS max_eff_to_dttm,
            m_1.stg_duration + m_1.ods_duration AS diff_eff_from_eff_to,
            m_1.err_stts_stg,
            m_1.err_stts_ods,
            m_1.alive_ods,
            m_1.status_log,
            m_1.node_type_src_id,
            m_1.node_type_cd,
            m_1.wf_loading_id,
            m_1.wf_id,
            m_1.avg_start_time,
            m_1.today_start,
            m_1.avg_ods_duration,
            m_1.err_stts_ods AS stts_nm,
            m_1.status_log AS log
           FROM dg_full.vmeta_get_metrics m_1
        UNION ALL
         SELECT c_1.nspname AS sch_name,
            c_1.relname AS tbl_name,
            c_1.started AS max_eff_from_dttm,
            c_1.created_at AS max_eff_to_dttm,
            c_1.stg_duration + c_1.ods_duration AS diff_eff_from_eff_to,
            c_1.err_stts_stg,
            c_1.stts_nm AS err_stts_ods,
            c_1.alive_ods,
            c_1.status_log,
            c_1.node_type_src_id,
            c_1.node_type_cd,
            c_1.wf_loading_id,
            c_1.wf_id,
            c_1.avg_start_time,
            c_1.today_start,
            c_1.avg_ods_duration,
            c_1.stts_nm,
            c_1.log
           FROM dg_full.vmeta_get_metrics_ctl c_1
        UNION ALL
         SELECT t_1.sch_name,
            t_1.tbl_name,
            t_1.max_eff_from_dttm,
            t_1.max_eff_to_dttm,
            t_1.diff_eff_from_eff_to,
            NULL::text AS err_stts_stg,
            NULL::text AS err_stts_ods,
            NULL::text AS alive_ods,
            NULL::text AS status_log,
            '1'::bigint AS node_type_src_id,
            'Table'::text AS node_type_cd,
            NULL::bigint AS wf_loading_id,
            NULL::bigint AS wf_id,
            NULL::interval AS avg_start_time,
            NULL::interval AS today_start,
            NULL::interval AS avg_ods_duration,
            NULL::text AS stts_nm,
            NULL::text AS log
           FROM s_grnplm_ld_cib_gm_dsc_dcp_dm.hfact_max_load_date t_1
        ), temp_pr_5 AS (
         SELECT (h.schema_src_id::text || '.'::text) || h.object_src_id::text AS node_id,
            h.property_val
           FROM dg_full.vmeta_property_hsat h
          WHERE 1 = 1 AND h.property_type_src_id = 5
        ), max_fact_execute AS (
         SELECT o.wf_id,
            lower(o.sch_name) AS sch_name,
            lower(o.tbl_name) AS tbl_name,
            max(o.max_eff_to_dttm) AS max_eff_to_dttm
           FROM fact_ctl_ods o
          WHERE 1 = 1
          GROUP BY o.wf_id, lower(o.sch_name), lower(o.tbl_name)
        )
 SELECT lower(t.sch_name) AS sch_name,
    lower(t.tbl_name) AS tbl_name,
    (lower(t.sch_name) || '.'::text) || lower(t.tbl_name) AS node_id,
    t.max_eff_from_dttm,
    t.max_eff_to_dttm,
    t.diff_eff_from_eff_to,
    GREATEST(t.max_eff_from_dttm, t.max_eff_to_dttm) AS max_dttm,
    COALESCE(pr_5.property_val, 'daily'::text) AS tbl_type,
        CASE
            WHEN m.max_eff_to_dttm IS NOT NULL THEN 1
            ELSE 0
        END AS fl_max_fact_execute,
    now() AS tbl_load_dttm,
    t.err_stts_stg,
    t.err_stts_ods,
    t.alive_ods,
    t.status_log,
    t.node_type_src_id,
    t.node_type_cd,
    t.wf_loading_id,
    t.wf_id,
    t.avg_start_time,
    t.today_start,
    t.avg_ods_duration,
    t.stts_nm,
    t.log
   FROM fact_ctl_ods t
     LEFT JOIN max_fact_execute m ON t.wf_id = m.wf_id AND lower(t.sch_name) = m.sch_name AND lower(t.tbl_name) = m.tbl_name AND t.max_eff_to_dttm = m.max_eff_to_dttm
     LEFT JOIN temp_pr_5 pr_5 ON ((lower(t.sch_name) || '.'::text) || lower(t.tbl_name)) = pr_5.node_id
  WHERE 1 = 1;


-- dg_full.vmeta_get_distribution_key source

CREATE OR REPLACE VIEW dg_full.vmeta_get_distribution_key
AS SELECT pgn.nspname AS schema_name,
    pgc.relname AS table_name,
    t.tableowner AS table_owner,
        CASE
            WHEN pg_get_table_distributedby(pgc.oid) = 'DISTRIBUTED RANDOMLY'::text THEN 'RANDOMLY'::text
            WHEN ("position"(pg_get_table_distributedby(pgc.oid), ')'::text) - ("position"(pg_get_table_distributedby(pgc.oid), 'DISTRIBUTED BY ('::text) + 16)) <= 0 THEN '-'::text
            ELSE "substring"(pg_get_table_distributedby(pgc.oid), "position"(pg_get_table_distributedby(pgc.oid), 'DISTRIBUTED BY ('::text) + 16, "position"(pg_get_table_distributedby(pgc.oid), ')'::text) - ("position"(pg_get_table_distributedby(pgc.oid), 'DISTRIBUTED BY ('::text) + 16))
        END::name AS distribution_keys,
    pg_get_table_distributedby(pgc.oid) AS distribution_keys_full,
        CASE pgc.relstorage
            WHEN 'a'::"char" THEN ' append-optimized'::text
            WHEN 'c'::"char" THEN 'column-oriented'::text
            WHEN 'h'::"char" THEN 'heap'::text
            WHEN 'v'::"char" THEN 'virtual'::text
            WHEN 'x'::"char" THEN 'external table'::text
            ELSE NULL::text
        END AS data_storage_mode,
    pgc.oid
   FROM pg_class pgc
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN pg_tables t ON pgc.relname = t.tablename AND t.schemaname = pgn.nspname
     JOIN dg_full.meta_schema_ref_table msrt ON pgn.nspname = msrt.schema_src_id::name AND msrt.src_cd::text = 'GP'::text
  WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"])) AND (pgc.relstorage <> ALL (ARRAY['x'::"char", 'v'::"char"])) AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid));


-- dg_full.vmeta_get_distribution_key2 source

CREATE OR REPLACE VIEW dg_full.vmeta_get_distribution_key2
AS SELECT a.schema_name,
    a.table_name,
    max(pgc.relpages) AS relpages,
    max(pgc.reltuples) AS reltuples,
    ( SELECT array_to_string(ARRAY( SELECT get_distribution_key.distribution_keys
                   FROM s_grnplm_ld_cib_gm_dsc_dcp_dm.get_distribution_key
                  WHERE get_distribution_key.schema_name = a.schema_name AND get_distribution_key.table_name = a.table_name), ', '::text) AS array_to_string) AS distkey
   FROM dg_full.vmeta_get_distribution_key a,
    pg_class pgc,
    pg_namespace pgn
  WHERE a.table_name = pgc.relname AND pgc.relnamespace = pgn.oid AND a.schema_name = pgn.nspname AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"])) AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid))
  GROUP BY a.schema_name, a.table_name;


-- dg_full.vmeta_get_distribution_key3 source

CREATE OR REPLACE VIEW dg_full.vmeta_get_distribution_key3
AS SELECT a.schema_name,
    a.table_name,
    max(pgc.relpages) AS relpages,
    max(pgc.reltuples) AS reltuples,
    ( SELECT array_to_string(ARRAY( SELECT dkey.distributionkey
                   FROM ( SELECT pgn_1.nspname AS schemaname,
                            pgc_1.relname AS tablename,
                            pga.attname AS distributionkey,
                            distrokey.attnum
                           FROM ( SELECT gdp.localoid,
CASE
 WHEN array_upper(gdp.distkey, 1) > 0 THEN unnest(gdp.distkey)
 ELSE NULL::smallint
END AS attnum
                                   FROM gp_distribution_policy gdp
                                  ORDER BY gdp.localoid) distrokey
                             JOIN pg_class pgc_1 ON distrokey.localoid = pgc_1.oid
                             JOIN pg_namespace pgn_1 ON pgc_1.relnamespace = pgn_1.oid
                             JOIN dg_full.meta_schema_ref_table msrt ON pgn_1.nspname = msrt.schema_src_id::name AND msrt.src_cd::text = 'GP'::text
                             LEFT JOIN pg_attribute pga ON distrokey.attnum = pga.attnum AND distrokey.localoid = pga.attrelid
                          WHERE 1 = 1 AND (pgc_1.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"])) AND NOT (EXISTS ( SELECT 1
                                   FROM pg_inherits i
                                  WHERE i.inhrelid = pgc_1.oid))
                          ORDER BY pgn_1.nspname, pgc_1.relname, distrokey.attnum) dkey
                  WHERE dkey.schemaname = a.schema_name AND dkey.tablename = a.table_name), ', '::text) AS array_to_string) AS distkey
   FROM dg_full.vmeta_get_distribution_key a,
    pg_class pgc,
    pg_namespace pgn
  WHERE a.table_name = pgc.relname AND pgc.relnamespace = pgn.oid AND a.schema_name = pgn.nspname
  GROUP BY a.schema_name, a.table_name;


-- dg_full.vmeta_get_distribution_key4 source

CREATE OR REPLACE VIEW dg_full.vmeta_get_distribution_key4
AS SELECT DISTINCT dkey.schemaname,
    dkey.tablename,
    dkey.threshold,
    dkey.relpages,
    dkey.reltuples,
    count(dkey.distributionkey) OVER (PARTITION BY dkey.schemaname, dkey.tablename) AS noofcolindistkey,
    array_to_string(array_agg(dkey.distributionkey) OVER (PARTITION BY dkey.schemaname, dkey.tablename), ','::text) AS distkey
   FROM ( SELECT pgn.nspname AS schemaname,
            pgc.relname AS tablename,
            pga.attname AS distributionkey,
            distrokey.attnum,
            '72 hours'::text AS threshold,
            pgc.relpages,
            pgc.reltuples
           FROM ( SELECT gdp.localoid,
                        CASE
                            WHEN array_upper(gdp.distkey, 1) > 0 THEN unnest(gdp.distkey)
                            ELSE NULL::smallint
                        END AS attnum
                   FROM gp_distribution_policy gdp
                  ORDER BY gdp.localoid) distrokey
             JOIN pg_class pgc ON distrokey.localoid = pgc.oid
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table msrt ON pgn.nspname = msrt.schema_src_id::name AND msrt.src_cd::text = 'GP'::text
             LEFT JOIN pg_attribute pga ON distrokey.attnum = pga.attnum AND distrokey.localoid = pga.attrelid
          WHERE 1 = 1 AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"])) AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid))
          ORDER BY pgn.nspname, pgc.relname, distrokey.attnum) dkey;


-- dg_full.vmeta_get_metrics source

CREATE OR REPLACE VIEW dg_full.vmeta_get_metrics
AS WITH tmp_metric0 AS (
         SELECT t1.created_at,
            t1.wf_id,
            t1.wf_loading_id,
            t1.value,
            t1.category,
            t1.nspname,
            t1.relname,
            t1.name,
            t1.labels #>> '{started}'::text[] AS labels_started,
            t1.created_at AS labels_finished,
            t1.labels #>> '{started_stg}'::text[] AS labels_started_stg,
            t1.labels #>> '{finished_stg}'::text[] AS labels_finished_stg,
            t1.labels #>> '{started_ods}'::text[] AS labels_started_ods,
            t1.labels #>> '{finished_ods}'::text[] AS labels_finished_ods,
            t1.labels #>> '{err_stts_stg}'::text[] AS labels_err_stts_stg,
            t1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_ods,
            t1.labels #>> '{started_mart}'::text[] AS labels_started_mart,
            t1.labels #>> '{finished_mart}'::text[] AS labels_finished_mart,
            t1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_mart
           FROM s_grnplm_as_cib_gm_meta.tibds_mertics t1
          WHERE 1 = 1 AND t1.name = 'duration'::text
        UNION ALL
         SELECT m_1.created_at,
            m_1.wf_id,
            m_1.wf_loading_id,
            m_1.value,
            m_1.category,
            m_1.nspname,
            m_1.relname,
            m_1.name,
            m_1.labels #>> '{started}'::text[] AS labels_started,
            m_1.created_at AS labels_finished,
            m_1.labels #>> '{started_stg}'::text[] AS labels_started_stg,
            m_1.labels #>> '{finished_stg}'::text[] AS labels_finished_stg,
            m_1.labels #>> '{started_ods}'::text[] AS labels_started_ods,
            m_1.labels #>> '{finished_ods}'::text[] AS labels_finished_ods,
            m_1.labels #>> '{err_stts_stg}'::text[] AS labels_err_stts_stg,
            m_1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_ods,
            m_1.labels #>> '{started_mart}'::text[] AS labels_started_mart,
            m_1.labels #>> '{finished_mart}'::text[] AS labels_finished_mart,
            m_1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_mart
           FROM s_grnplm_as_cib_gm_meta_core.metrics m_1
          WHERE 1 = 1 AND m_1.name = 'duration'::text
        ), tmp_metric AS (
         SELECT t0.created_at,
            t0.wf_id,
            t0.wf_loading_id,
            t0.value,
            t0.category,
            t0.nspname,
            t0.relname,
            t0.name,
            t0.labels_started,
                CASE
                    WHEN t0.labels_started IS NOT NULL THEN t0.labels_finished
                    ELSE NULL::timestamp without time zone
                END AS labels_finished,
            t0.labels_started_stg,
            t0.labels_finished_stg,
            t0.labels_started_ods,
            t0.labels_finished_ods,
            t0.labels_err_stts_stg,
            t0.labels_err_stts_ods,
            t0.labels_started_mart,
            t0.labels_finished_mart,
            t0.labels_err_stts_mart
           FROM tmp_metric0 t0
        ), tmp_dur AS (
         SELECT tt.wf_id,
            tt.wf_loading_id,
            sum(tt.value) AS wf_value,
            sum(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.value
                    ELSE 0::numeric
                END) AS stg_value,
            sum(
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.value
                    ELSE 0::numeric
                END) AS ods_value,
            max(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END) AS nspname_stg,
            max(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END) AS relname_stg,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname ~~ '%stg%'::text THEN tt.labels_started::timestamp without time zone
                    ELSE tt.labels_started_stg::timestamp without time zone
                END) AS started_stg,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname ~~ '%stg%'::text THEN tt.created_at
                    ELSE tt.labels_finished_stg::timestamp without time zone
                END) AS finished_stg,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END AS nspname_ods,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END AS relname_ods,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname !~~ '%stg%'::text THEN tt.labels_started::timestamp without time zone
                    ELSE COALESCE(tt.labels_started_ods::timestamp without time zone, tt.labels_started_mart::timestamp without time zone)
                END) AS started_ods,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname !~~ '%stg%'::text THEN tt.created_at
                    ELSE COALESCE(tt.labels_finished_ods::timestamp without time zone, tt.labels_finished_mart::timestamp without time zone)
                END) AS finished_ods,
            max(tt.labels_err_stts_stg) AS err_stts_stg,
            max(COALESCE(tt.labels_err_stts_ods, tt.labels_err_stts_mart)) AS err_stts_ods
           FROM tmp_metric tt
          GROUP BY tt.wf_id, tt.wf_loading_id,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END
        ), tmp_metric2 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.nspname_stg,
            d.relname_stg,
            d.started_stg,
            d.finished_stg,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.err_stts_stg,
            d.err_stts_ods,
            d.finished_ods - d.started_ods AS ods_value,
            d.finished_stg - d.started_stg AS stg_value,
            COALESCE(d.finished_ods - d.started_ods, '00:00:00'::interval) + COALESCE(d.finished_stg - d.started_stg, '00:00:00'::interval) AS wf_value
           FROM tmp_dur d
        ), tmp_metric1 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.wf_value AS wf_duration,
            date_part('epoch'::text, d.wf_value)::bigint AS wf_duration_sec,
            avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_wf_duration_sec,
            stddev(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_wf_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.wf_value)::bigint::numeric - (avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (min(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS min_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (max(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS max_wf_duration_sec,
                CASE
                    WHEN COALESCE(d.started_stg, d.started_ods) = (max(COALESCE(d.started_stg, d.started_ods)) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS last_wf_duration_sec,
            d.nspname_stg,
            d.relname_stg,
            d.started_stg,
            d.finished_stg,
            d.stg_value AS stg_duration,
            date_part('epoch'::text, d.stg_value)::bigint AS stg_duration_sec,
            avg(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg) AS avg_stg_duration_sec,
            stddev(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg) AS stddev_stg_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.stg_value)::bigint::numeric - (avg(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg))) > 30::numeric THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_stg_duration_sec,
                CASE
                    WHEN d.stg_value = (min(d.stg_value) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS min_stg_duration_sec,
                CASE
                    WHEN d.stg_value = (max(d.stg_value) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS max_stg_duration_sec,
                CASE
                    WHEN d.started_stg = (max(d.started_stg) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS last_stg_duration_sec,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.ods_value AS ods_duration,
            avg(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration,
            date_part('epoch'::text, d.ods_value)::bigint AS ods_duration_sec,
            avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration_sec,
            stddev(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_ods_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.ods_value)::bigint::numeric - (avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (min(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS min_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (max(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS max_ods_duration_sec,
                CASE
                    WHEN d.started_ods = (max(d.started_ods) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS last_ods_duration_sec,
                CASE
                    WHEN d.relname_stg IS NOT NULL THEN
                    CASE
                        WHEN d.err_stts_stg IS NOT NULL THEN 'WAITING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NULL AND (now() - d.started_stg::timestamp with time zone) > '01:00:00'::interval THEN 'WAITING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NULL AND (now() - d.started_stg::timestamp with time zone) <= '01:00:00'::interval THEN 'RUNNING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NOT NULL THEN 'SUCCESS'::text
                        ELSE NULL::text
                    END
                    ELSE 'N\A'::text
                END AS err_stts_stg,
                CASE
                    WHEN d.relname_ods IS NOT NULL THEN
                    CASE
                        WHEN d.err_stts_ods IS NOT NULL THEN 'WAITING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NULL AND (now() - d.started_ods::timestamp with time zone) > '01:00:00'::interval THEN 'WAITING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NULL AND (now() - d.started_ods::timestamp with time zone) <= '01:00:00'::interval THEN 'RUNNING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NOT NULL THEN 'SUCCESS'::text
                        ELSE NULL::text
                    END
                    ELSE 'N\A'::text
                END AS err_stts_ods,
            d.started_ods::time without time zone::interval AS today_start,
            avg(d.started_ods::time without time zone::interval) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_start_time
           FROM tmp_metric2 d
        )
 SELECT m.wf_loading_id,
    COALESCE(m.finished_ods::timestamp(3) without time zone, m.finished_stg::timestamp(3) without time zone) AS created_at,
    COALESCE(m.started_stg, m.started_ods) AS started,
    COALESCE(m.relname_ods, m.relname_stg) AS relname,
    m.stg_duration,
    m.ods_duration,
    COALESCE(m.nspname_ods, m.nspname_stg) AS nspname,
    m.wf_duration_sec AS ods_duration_sec,
    m.avg_wf_duration_sec AS avg_ods_duration_sec,
    m.stddev_wf_duration_sec AS stddev_ods_duration_sec,
    m.diff30_wf_duration_sec AS diff30_ods_duration_sec,
    m.min_wf_duration_sec AS min_ods_duration_sec,
    m.max_wf_duration_sec AS max_ods_duration_sec,
    m.last_wf_duration_sec AS last_ods_duration_sec,
    m.wf_duration,
    m.err_stts_stg,
    m.err_stts_ods,
    NULL::text AS alive_ods,
    NULL::text AS status_log,
    n.node_type_src_id,
    nt.node_type_cd,
    m.wf_id,
    m.avg_start_time,
    m.today_start,
    m.avg_ods_duration
   FROM tmp_metric1 m
     LEFT JOIN dg_full.meta_node_ref_table n ON COALESCE(m.nspname_ods, m.nspname_stg) = n.schema_src_id::text AND COALESCE(m.relname_ods, m.relname_stg) = n.node_src_id::text
     LEFT JOIN dg_full.meta_node_type_ref_table nt ON nt.node_type_src_id = n.node_type_src_id
  WHERE 1 = 1 AND (nt.node_type_cd::text = ANY (ARRAY['Table'::character varying::text, 'View'::character varying::text, 'Function'::character varying::text]));


-- dg_full.vmeta_get_metrics_ctl source

CREATE OR REPLACE VIEW dg_full.vmeta_get_metrics_ctl
AS WITH tmp_metric AS (
         SELECT t1.wf_id,
            t1.id AS wf_loading_id,
            t1.status AS labels_err_stts_ods,
            t1.alive AS labels_alive_ods,
            t1.status_log,
            'histogram'::text AS category,
            w.category_nm AS nspname,
            w.name_ AS relname,
            'duration'::text AS name,
            t2.stts_event_wait,
            t2.stts_time_wait,
            COALESCE(t2.start_dttm, t2.stts_event_wait, t2.stts_time_wait) AS labels_started_ods,
            t2.end_dttm AS labels_finished_ods,
            t2.end_dttm - t2.start_dttm AS value,
            t2.stts_nm,
            t2.log
           FROM dg_full.vctl_loading t1
             JOIN dg_full.vctl_wf w ON t1.wf_id = w.id
             LEFT JOIN dg_full.vctl_loading_status t2 ON t1.wf_id = t2.wf_id AND t1.id = t2.wf_loading_id
          WHERE 1 = 1 AND w.deleted = false AND (w.profile_id = ANY (ARRAY[150, 329, 334])) AND (w.id IN ( SELECT cp1.wf_id
                   FROM dg_full.vctl_param cp1
                  WHERE 1 = 1 AND lower(cp1.param) ~~ '%connectionlake%'::text AND cp1.prior_value ~~ '%TIB%'::text
                  GROUP BY cp1.wf_id))
        ), tmp_dur AS (
         SELECT tt.wf_id,
            tt.wf_loading_id,
            sum(tt.value) AS wf_value,
            sum(0::numeric) AS stg_value,
            sum(tt.value) AS ods_value,
            NULL::text AS nspname_stg,
            NULL::text AS relname_stg,
            tt.nspname AS nspname_ods,
            tt.relname AS relname_ods,
            max(tt.labels_started_ods) AS started_ods,
            max(tt.labels_finished_ods) AS finished_ods,
            max(tt.labels_err_stts_ods) AS err_stts_ods,
            max(tt.labels_alive_ods) AS alive_ods,
            max(tt.status_log) AS status_log,
            max(tt.stts_nm) AS stts_nm,
            max(tt.log) AS log
           FROM tmp_metric tt
          GROUP BY tt.wf_id, tt.wf_loading_id, tt.nspname, tt.relname
        ), tmp_metric1 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.wf_value AS wf_duration,
            date_part('epoch'::text, d.wf_value)::bigint AS wf_duration_sec,
            avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_wf_duration_sec,
            stddev(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_wf_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.wf_value)::bigint::numeric - (avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (min(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS min_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (max(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS max_wf_duration_sec,
                CASE
                    WHEN d.started_ods = (max(d.started_ods) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS last_wf_duration_sec,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.ods_value AS ods_duration,
            date_part('epoch'::text, d.ods_value)::bigint AS ods_duration_sec,
            avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration_sec,
            stddev(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_ods_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.ods_value)::bigint::numeric - (avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (min(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS min_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (max(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS max_ods_duration_sec,
                CASE
                    WHEN d.started_ods = (max(d.started_ods) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS last_ods_duration_sec,
            d.err_stts_ods,
            d.alive_ods,
            d.status_log,
            d.stts_nm,
            d.log,
            d.started_ods::time without time zone::interval AS today_start,
            avg(d.started_ods::time without time zone::interval) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_start_time,
            avg(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration
           FROM tmp_dur d
        )
 SELECT m.wf_loading_id::bigint AS wf_loading_id,
    m.finished_ods::timestamp(3) without time zone AS created_at,
    m.started_ods AS started,
    m.relname_ods AS relname,
    NULL::interval AS stg_duration,
    m.ods_duration,
    m.nspname_ods AS nspname,
    m.wf_duration_sec AS ods_duration_sec,
    m.avg_wf_duration_sec AS avg_ods_duration_sec,
    m.stddev_wf_duration_sec AS stddev_ods_duration_sec,
    m.diff30_wf_duration_sec AS diff30_ods_duration_sec,
    m.min_wf_duration_sec AS min_ods_duration_sec,
    m.max_wf_duration_sec AS max_ods_duration_sec,
    m.last_wf_duration_sec AS last_ods_duration_sec,
    m.wf_duration,
    NULL::text AS err_stts_stg,
    m.err_stts_ods,
    m.alive_ods,
    m.status_log,
    n.node_type_src_id,
    nt.node_type_cd,
    m.wf_id,
    m.stts_nm,
    m.log,
    m.today_start,
    m.avg_start_time,
    m.avg_ods_duration
   FROM tmp_metric1 m
     LEFT JOIN dg_full.meta_node_ref_table n ON m.nspname_ods = n.schema_src_id::text AND m.relname_ods = n.node_src_id::text
     LEFT JOIN dg_full.meta_node_type_ref_table nt ON nt.node_type_src_id = n.node_type_src_id
  WHERE 1 = 1 AND (nt.node_type_cd::text = ANY (ARRAY['Entity'::character varying::text, 'Flow'::character varying::text]));


-- dg_full.vmeta_get_metrics_fvv_test source

CREATE OR REPLACE VIEW dg_full.vmeta_get_metrics_fvv_test
AS WITH tmp_metric0 AS (
         SELECT t1.created_at,
            t1.wf_id,
            t1.wf_loading_id,
            t1.value,
            t1.category,
            t1.nspname,
            t1.relname,
            t1.name,
            t1.labels #>> '{started}'::text[] AS labels_started,
            t1.created_at AS labels_finished,
            t1.labels #>> '{started_stg}'::text[] AS labels_started_stg,
            t1.labels #>> '{finished_stg}'::text[] AS labels_finished_stg,
            t1.labels #>> '{started_ods}'::text[] AS labels_started_ods,
            t1.labels #>> '{finished_ods}'::text[] AS labels_finished_ods,
            t1.labels #>> '{err_stts_stg}'::text[] AS labels_err_stts_stg,
            t1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_ods,
            t1.labels #>> '{started_mart}'::text[] AS labels_started_mart,
            t1.labels #>> '{finished_mart}'::text[] AS labels_finished_mart,
            t1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_mart
           FROM s_grnplm_as_cib_gm_meta.tibds_mertics t1
          WHERE 1 = 1 AND t1.name = 'duration'::text
        UNION ALL
         SELECT m_1.created_at,
            m_1.wf_id,
            m_1.wf_loading_id,
            m_1.value,
            m_1.category,
            m_1.nspname,
            m_1.relname,
            m_1.name,
            m_1.labels #>> '{started}'::text[] AS labels_started,
            m_1.created_at AS labels_finished,
            m_1.labels #>> '{started_stg}'::text[] AS labels_started_stg,
            m_1.labels #>> '{finished_stg}'::text[] AS labels_finished_stg,
            m_1.labels #>> '{started_ods}'::text[] AS labels_started_ods,
            m_1.labels #>> '{finished_ods}'::text[] AS labels_finished_ods,
            m_1.labels #>> '{err_stts_stg}'::text[] AS labels_err_stts_stg,
            m_1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_ods,
            m_1.labels #>> '{started_mart}'::text[] AS labels_started_mart,
            m_1.labels #>> '{finished_mart}'::text[] AS labels_finished_mart,
            m_1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_mart
           FROM s_grnplm_as_cib_gm_meta_core.metrics m_1
          WHERE 1 = 1 AND m_1.name = 'duration'::text
        ), tmp_metric AS (
         SELECT t0.created_at,
            t0.wf_id,
            t0.wf_loading_id,
            t0.value,
            t0.category,
            t0.nspname,
            t0.relname,
            t0.name,
            t0.labels_started,
                CASE
                    WHEN t0.labels_started IS NOT NULL THEN t0.labels_finished
                    ELSE NULL::timestamp without time zone
                END AS labels_finished,
            t0.labels_started_stg,
            t0.labels_finished_stg,
            t0.labels_started_ods,
            t0.labels_finished_ods,
            t0.labels_err_stts_stg,
            t0.labels_err_stts_ods,
            t0.labels_started_mart,
            t0.labels_finished_mart,
            t0.labels_err_stts_mart
           FROM tmp_metric0 t0
        ), tmp_dur AS (
         SELECT tt.wf_id,
            tt.wf_loading_id,
            sum(tt.value) AS wf_value,
            sum(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.value
                    ELSE 0::numeric
                END) AS stg_value,
            sum(
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.value
                    ELSE 0::numeric
                END) AS ods_value,
            max(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END) AS nspname_stg,
            max(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END) AS relname_stg,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname ~~ '%stg%'::text THEN tt.labels_started::timestamp without time zone
                    ELSE tt.labels_started_stg::timestamp without time zone
                END) AS started_stg,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname ~~ '%stg%'::text THEN tt.created_at
                    ELSE tt.labels_finished_stg::timestamp without time zone
                END) AS finished_stg,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END AS nspname_ods,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END AS relname_ods,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname !~~ '%stg%'::text THEN tt.labels_started::timestamp without time zone
                    ELSE COALESCE(tt.labels_started_ods::timestamp without time zone, tt.labels_started_mart::timestamp without time zone, tt.labels_started::timestamp without time zone)
                END) AS started_ods,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname !~~ '%stg%'::text THEN tt.created_at
                    ELSE COALESCE(tt.labels_finished_ods::timestamp without time zone, tt.labels_finished_mart::timestamp without time zone)
                END) AS finished_ods,
            max(tt.labels_err_stts_stg) AS err_stts_stg,
            max(COALESCE(tt.labels_err_stts_ods, tt.labels_err_stts_mart)) AS err_stts_ods
           FROM tmp_metric tt
          GROUP BY tt.wf_id, tt.wf_loading_id,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END
        ), tmp_metric2 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.nspname_stg,
            d.relname_stg,
            d.started_stg,
            d.finished_stg,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.err_stts_stg,
            d.err_stts_ods,
            d.finished_ods - d.started_ods AS ods_value,
            d.finished_stg - d.started_stg AS stg_value,
            COALESCE(d.finished_ods - d.started_ods, '00:00:00'::interval) + COALESCE(d.finished_stg - d.started_stg, '00:00:00'::interval) AS wf_value
           FROM tmp_dur d
        ), tmp_metric1 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.wf_value AS wf_duration,
            date_part('epoch'::text, d.wf_value)::bigint AS wf_duration_sec,
            avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_wf_duration_sec,
            stddev(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_wf_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.wf_value)::bigint::numeric - (avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (min(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS min_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (max(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS max_wf_duration_sec,
                CASE
                    WHEN COALESCE(d.started_stg, d.started_ods) = (max(COALESCE(d.started_stg, d.started_ods)) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS last_wf_duration_sec,
            d.nspname_stg,
            d.relname_stg,
            d.started_stg,
            d.finished_stg,
            d.stg_value AS stg_duration,
            date_part('epoch'::text, d.stg_value)::bigint AS stg_duration_sec,
            avg(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg) AS avg_stg_duration_sec,
            stddev(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg) AS stddev_stg_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.stg_value)::bigint::numeric - (avg(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg))) > 30::numeric THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_stg_duration_sec,
                CASE
                    WHEN d.stg_value = (min(d.stg_value) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS min_stg_duration_sec,
                CASE
                    WHEN d.stg_value = (max(d.stg_value) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS max_stg_duration_sec,
                CASE
                    WHEN d.started_stg = (max(d.started_stg) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS last_stg_duration_sec,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.ods_value AS ods_duration,
            avg(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration,
            date_part('epoch'::text, d.ods_value)::bigint AS ods_duration_sec,
            avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration_sec,
            stddev(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_ods_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.ods_value)::bigint::numeric - (avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (min(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS min_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (max(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS max_ods_duration_sec,
                CASE
                    WHEN d.started_ods = (max(d.started_ods) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS last_ods_duration_sec,
                CASE
                    WHEN d.relname_stg IS NOT NULL THEN
                    CASE
                        WHEN d.err_stts_stg IS NOT NULL THEN 'WAITING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NULL AND (now() - d.started_stg::timestamp with time zone) > '01:00:00'::interval THEN 'WAITING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NULL AND (now() - d.started_stg::timestamp with time zone) <= '01:00:00'::interval THEN 'RUNNING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NOT NULL THEN 'SUCCESS'::text
                        ELSE NULL::text
                    END
                    ELSE 'N\A'::text
                END AS err_stts_stg,
                CASE
                    WHEN d.relname_ods IS NOT NULL THEN
                    CASE
                        WHEN d.err_stts_ods IS NOT NULL THEN 'WAITING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NULL AND (now() - d.started_ods::timestamp with time zone) > '01:00:00'::interval THEN 'WAITING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NULL AND (now() - d.started_ods::timestamp with time zone) <= '01:00:00'::interval THEN 'RUNNING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NOT NULL THEN 'SUCCESS'::text
                        ELSE NULL::text
                    END
                    ELSE 'N\A'::text
                END AS err_stts_ods,
            d.started_ods::time without time zone::interval AS today_start,
            avg(d.started_ods::time without time zone::interval) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_start_time
           FROM tmp_metric2 d
        )
 SELECT m.wf_loading_id,
    m.finished_ods::timestamp(3) without time zone AS created_at,
    COALESCE(m.started_stg, m.started_ods) AS started,
    COALESCE(m.relname_ods, m.relname_stg) AS relname,
    m.stg_duration,
    m.ods_duration,
    COALESCE(m.nspname_ods, m.nspname_stg) AS nspname,
    m.wf_duration_sec AS ods_duration_sec,
    m.avg_wf_duration_sec AS avg_ods_duration_sec,
    m.stddev_wf_duration_sec AS stddev_ods_duration_sec,
    m.diff30_wf_duration_sec AS diff30_ods_duration_sec,
    m.min_wf_duration_sec AS min_ods_duration_sec,
    m.max_wf_duration_sec AS max_ods_duration_sec,
    m.last_wf_duration_sec AS last_ods_duration_sec,
    m.wf_duration,
    m.err_stts_stg,
    m.err_stts_ods,
    NULL::text AS alive_ods,
    NULL::text AS status_log,
    n.node_type_src_id,
    nt.node_type_cd,
    m.wf_id,
    m.avg_start_time,
    m.today_start,
    m.avg_ods_duration
   FROM tmp_metric1 m
     LEFT JOIN dg_full.meta_node_ref_table n ON COALESCE(m.nspname_ods, m.nspname_stg) = n.schema_src_id::text AND COALESCE(m.relname_ods, m.relname_stg) = n.node_src_id::text
     LEFT JOIN dg_full.meta_node_type_ref_table nt ON nt.node_type_src_id = n.node_type_src_id
  WHERE 1 = 1 AND (nt.node_type_cd::text = ANY (ARRAY['Table'::character varying::text, 'View'::character varying::text, 'Function'::character varying::text]));


-- dg_full.vmeta_get_metrics_lg source

CREATE OR REPLACE VIEW dg_full.vmeta_get_metrics_lg
AS WITH tmp_metric0 AS (
         SELECT t1.created_at,
            t1.wf_id,
            t1.wf_loading_id,
            t1.value,
            t1.category,
            t1.nspname,
            t1.relname,
            t1.name,
            t1.labels #>> '{started}'::text[] AS labels_started,
            t1.created_at AS labels_finished,
            t1.labels #>> '{started_stg}'::text[] AS labels_started_stg,
            t1.labels #>> '{finished_stg}'::text[] AS labels_finished_stg,
            t1.labels #>> '{started_ods}'::text[] AS labels_started_ods,
            t1.labels #>> '{finished_ods}'::text[] AS labels_finished_ods,
            t1.labels #>> '{err_stts_stg}'::text[] AS labels_err_stts_stg,
            t1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_ods,
            t1.labels #>> '{started_mart}'::text[] AS labels_started_mart,
            t1.labels #>> '{finished_mart}'::text[] AS labels_finished_mart,
            t1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_mart
           FROM s_grnplm_as_cib_gm_meta.tibds_mertics t1
          WHERE 1 = 1 AND t1.name = 'duration'::text
        UNION ALL
         SELECT m_1.created_at,
            m_1.wf_id,
            m_1.wf_loading_id,
            m_1.value,
            m_1.category,
            m_1.nspname,
            m_1.relname,
            m_1.name,
            m_1.labels #>> '{started}'::text[] AS labels_started,
            m_1.created_at AS labels_finished,
            m_1.labels #>> '{started_stg}'::text[] AS labels_started_stg,
            m_1.labels #>> '{finished_stg}'::text[] AS labels_finished_stg,
            m_1.labels #>> '{started_ods}'::text[] AS labels_started_ods,
            m_1.labels #>> '{finished_ods}'::text[] AS labels_finished_ods,
            m_1.labels #>> '{err_stts_stg}'::text[] AS labels_err_stts_stg,
            m_1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_ods,
            m_1.labels #>> '{started_mart}'::text[] AS labels_started_mart,
            m_1.labels #>> '{finished_mart}'::text[] AS labels_finished_mart,
            m_1.labels #>> '{err_stts_ods}'::text[] AS labels_err_stts_mart
           FROM s_grnplm_as_cib_gm_meta_core.metrics m_1
          WHERE 1 = 1 AND m_1.name = 'duration'::text
        ), tmp_metric AS (
         SELECT t0.created_at,
            t0.wf_id,
            t0.wf_loading_id,
            t0.value,
            t0.category,
            t0.nspname,
            t0.relname,
            t0.name,
            t0.labels_started,
                CASE
                    WHEN t0.labels_started IS NOT NULL THEN t0.labels_finished
                    ELSE NULL::timestamp without time zone
                END AS labels_finished,
            t0.labels_started_stg,
            t0.labels_finished_stg,
            t0.labels_started_ods,
            t0.labels_finished_ods,
            t0.labels_err_stts_stg,
            t0.labels_err_stts_ods,
            t0.labels_started_mart,
            t0.labels_finished_mart,
            t0.labels_err_stts_mart
           FROM tmp_metric0 t0
        ), tmp_dur AS (
         SELECT tt.wf_id,
            tt.wf_loading_id,
            sum(tt.value) AS wf_value,
            sum(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.value
                    ELSE 0::numeric
                END) AS stg_value,
            sum(
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.value
                    ELSE 0::numeric
                END) AS ods_value,
            max(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END) AS nspname_stg,
            max(
                CASE
                    WHEN tt.nspname ~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END) AS relname_stg,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname ~~ '%stg%'::text THEN tt.labels_started::timestamp without time zone
                    ELSE tt.labels_started_stg::timestamp without time zone
                END) AS started_stg,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname ~~ '%stg%'::text THEN tt.created_at
                    ELSE tt.labels_finished_stg::timestamp without time zone
                END) AS finished_stg,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END AS nspname_ods,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END AS relname_ods,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname !~~ '%stg%'::text THEN tt.labels_started::timestamp without time zone
                    ELSE COALESCE(tt.labels_started_ods::timestamp without time zone, tt.labels_started_mart::timestamp without time zone)
                END) AS started_ods,
            max(
                CASE
                    WHEN tt.labels_started IS NOT NULL AND tt.nspname !~~ '%stg%'::text THEN tt.created_at
                    ELSE COALESCE(tt.labels_finished_ods::timestamp without time zone, tt.labels_finished_mart::timestamp without time zone)
                END) AS finished_ods,
            max(tt.labels_err_stts_stg) AS err_stts_stg,
            max(COALESCE(tt.labels_err_stts_ods, tt.labels_err_stts_mart)) AS err_stts_ods
           FROM tmp_metric tt
          GROUP BY tt.wf_id, tt.wf_loading_id,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.nspname
                    ELSE NULL::text
                END,
                CASE
                    WHEN tt.nspname !~~ '%stg%'::text THEN tt.relname
                    ELSE NULL::text
                END
        ), tmp_metric2 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.nspname_stg,
            d.relname_stg,
            d.started_stg,
            d.finished_stg,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.err_stts_stg,
            d.err_stts_ods,
            d.finished_ods - d.started_ods AS ods_value,
            d.finished_stg - d.started_stg AS stg_value,
            COALESCE(d.finished_ods - d.started_ods, '00:00:00'::interval) + COALESCE(d.finished_stg - d.started_stg, '00:00:00'::interval) AS wf_value
           FROM tmp_dur d
        ), tmp_metric1 AS (
         SELECT d.wf_id,
            d.wf_loading_id,
            d.wf_value AS wf_duration,
            date_part('epoch'::text, d.wf_value)::bigint AS wf_duration_sec,
            avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_wf_duration_sec,
            stddev(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_wf_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.wf_value)::bigint::numeric - (avg(date_part('epoch'::text, d.wf_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (min(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS min_wf_duration_sec,
                CASE
                    WHEN d.wf_value = (max(d.wf_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS max_wf_duration_sec,
                CASE
                    WHEN COALESCE(d.started_stg, d.started_ods) = (max(COALESCE(d.started_stg, d.started_ods)) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.wf_value)::bigint
                    ELSE NULL::bigint
                END AS last_wf_duration_sec,
            d.nspname_stg,
            d.relname_stg,
            d.started_stg,
            d.finished_stg,
            d.stg_value AS stg_duration,
            date_part('epoch'::text, d.stg_value)::bigint AS stg_duration_sec,
            avg(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg) AS avg_stg_duration_sec,
            stddev(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg) AS stddev_stg_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.stg_value)::bigint::numeric - (avg(date_part('epoch'::text, d.stg_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg))) > 30::numeric THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_stg_duration_sec,
                CASE
                    WHEN d.stg_value = (min(d.stg_value) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS min_stg_duration_sec,
                CASE
                    WHEN d.stg_value = (max(d.stg_value) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS max_stg_duration_sec,
                CASE
                    WHEN d.started_stg = (max(d.started_stg) OVER (PARTITION BY d.wf_id, d.nspname_stg, d.relname_stg)) THEN date_part('epoch'::text, d.stg_value)::bigint
                    ELSE NULL::bigint
                END AS last_stg_duration_sec,
            d.nspname_ods,
            d.relname_ods,
            d.started_ods,
            d.finished_ods,
            d.ods_value AS ods_duration,
            avg(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration,
            date_part('epoch'::text, d.ods_value)::bigint AS ods_duration_sec,
            avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_ods_duration_sec,
            stddev(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS stddev_ods_duration_sec,
                CASE
                    WHEN (date_part('epoch'::text, d.ods_value)::bigint::numeric - (avg(date_part('epoch'::text, d.ods_value)::bigint) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods))) > 30::numeric THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS diff30_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (min(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS min_ods_duration_sec,
                CASE
                    WHEN d.ods_value = (max(d.ods_value) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS max_ods_duration_sec,
                CASE
                    WHEN d.started_ods = (max(d.started_ods) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods)) THEN date_part('epoch'::text, d.ods_value)::bigint
                    ELSE NULL::bigint
                END AS last_ods_duration_sec,
                CASE
                    WHEN d.relname_stg IS NOT NULL THEN
                    CASE
                        WHEN d.err_stts_stg IS NOT NULL THEN 'WAITING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NULL AND (now() - d.started_stg::timestamp with time zone) > '01:00:00'::interval THEN 'ERROR'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NULL AND (now() - d.started_stg::timestamp with time zone) <= '01:00:00'::interval THEN 'RUNNING'::text
                        WHEN d.started_stg IS NOT NULL AND d.finished_stg IS NOT NULL THEN 'SUCCESS'::text
                        ELSE NULL::text
                    END
                    ELSE 'N\A'::text
                END AS err_stts_stg,
                CASE
                    WHEN d.relname_ods IS NOT NULL THEN
                    CASE
                        WHEN d.err_stts_ods IS NOT NULL THEN 'WAITING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NULL AND (now() - d.started_ods::timestamp with time zone) > '01:00:00'::interval THEN 'ERROR'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NULL AND (now() - d.started_ods::timestamp with time zone) <= '01:00:00'::interval THEN 'RUNNING'::text
                        WHEN d.started_ods IS NOT NULL AND d.finished_ods IS NOT NULL THEN 'SUCCESS'::text
                        ELSE NULL::text
                    END
                    ELSE 'N\A'::text
                END AS err_stts_ods,
            d.started_ods::time without time zone::interval AS today_start,
            avg(d.started_ods::time without time zone::interval) OVER (PARTITION BY d.wf_id, d.nspname_ods, d.relname_ods) AS avg_start_time
           FROM tmp_metric2 d
        )
 SELECT m.wf_loading_id,
    COALESCE(m.finished_ods::timestamp(3) without time zone, m.finished_stg::timestamp(3) without time zone) AS created_at,
    COALESCE(m.started_stg, m.started_ods) AS started,
    COALESCE(m.relname_ods, m.relname_stg) AS relname,
    m.stg_duration,
    m.ods_duration,
    COALESCE(m.nspname_ods, m.nspname_stg) AS nspname,
    m.wf_duration_sec AS ods_duration_sec,
    m.avg_wf_duration_sec AS avg_ods_duration_sec,
    m.stddev_wf_duration_sec AS stddev_ods_duration_sec,
    m.diff30_wf_duration_sec AS diff30_ods_duration_sec,
    m.min_wf_duration_sec AS min_ods_duration_sec,
    m.max_wf_duration_sec AS max_ods_duration_sec,
    m.last_wf_duration_sec AS last_ods_duration_sec,
    m.wf_duration,
    m.err_stts_stg,
    m.err_stts_ods,
    NULL::text AS alive_ods,
    NULL::text AS status_log,
    n.node_type_src_id,
    nt.node_type_cd,
    m.wf_id,
    m.avg_start_time,
    m.today_start,
    m.avg_ods_duration
   FROM tmp_metric1 m
     LEFT JOIN dg_full.meta_node_ref_table n ON COALESCE(m.nspname_ods, m.nspname_stg) = n.schema_src_id::text AND COALESCE(m.relname_ods, m.relname_stg) = n.node_src_id::text
     LEFT JOIN dg_full.meta_node_type_ref_table nt ON nt.node_type_src_id = n.node_type_src_id
  WHERE 1 = 1 AND (nt.node_type_cd::text = ANY (ARRAY['Table'::character varying::text, 'View'::character varying::text, 'Function'::character varying::text]));


-- dg_full.vmeta_is_active_objects source

CREATE OR REPLACE VIEW dg_full.vmeta_is_active_objects
AS WITH sst AS (
         SELECT routines.routine_schema,
            routines.routine_name,
            routines.data_type,
            routines.routine_type,
            now() AS load_dttm
           FROM information_schema.routines
             JOIN dg_full.meta_schema_ref_table t ON routines.routine_schema::text = t.schema_src_id::text
          WHERE 1 = 1
        UNION ALL
         SELECT v.table_schema,
            v.table_name,
            NULL::text AS data_type,
            'VIEW'::text AS routine_type,
            now() AS load_dttm
           FROM information_schema.views v
             JOIN dg_full.meta_schema_ref_table t ON v.table_schema::text = t.schema_src_id::text
          WHERE 1 = 1
        UNION ALL
         SELECT v.table_schema,
            v.table_name,
            NULL::text AS data_type,
            'TABLE'::text AS routine_type,
            now() AS load_dttm
           FROM information_schema.tables v
             JOIN dg_full.meta_schema_ref_table t ON v.table_schema::text = t.schema_src_id::text
          WHERE 1 = 1 AND v.table_name::text !~~ '%_prt_%'::text
        )
 SELECT n.routine_schema AS n_routine_schema,
    n.routine_name AS n_routine_name,
    n.data_type AS n_data_type,
    n.routine_type AS n_routine_type,
    n.load_dttm AS n_load_dttm,
    o.schema_src_id::character varying(250) AS o_routine_schema,
    o.object_src_id::character varying(250) AS o_routine_name,
    NULL::character varying AS o_data_type,
    NULL::character varying AS o_routine_type,
    o.load_dttm::timestamp(0) without time zone AS o_load_dttm,
    o.property_val,
    ((('INSERT INTO dg_full.vmeta_property_hsat(property_id,schema_src_id,object_src_id,property_val,edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,property_type_src_id)
  values(-1, '''::text || n.routine_schema::text) || ''','''::text) || n.routine_name::text) || ''',''manual'',-1,current_timestamp, ''GP'',-1,''1999-01-01''::date,    ''2999-12-31''::date,current_timestamp,5);'::text AS st_5,
    ((('INSERT INTO dg_full.vmeta_property_hsat(property_id,schema_src_id,object_src_id,property_val,edge_id,load_dttm,src_cd,wf_load_id,eff_from_dttm,eff_to_dttm,last_seen_dttm,property_type_src_id)
  values(-1, '''::text || n.routine_schema::text) || ''','''::text) || n.routine_name::text) || ''',''1'',-1,current_timestamp, ''GP'',-1,''1999-01-01''::date,    ''2999-12-31''::date,current_timestamp,6);'::text AS st_6
   FROM sst n
     LEFT JOIN ( SELECT h.property_id,
            h.object_src_id,
            h.schema_src_id,
            h.edge_id,
            h.load_dttm,
            h.src_cd,
            h.wf_load_id,
            h.eff_from_dttm,
            h.eff_to_dttm,
            h.last_seen_dttm,
            h.property_type_src_id,
            h.property_val
           FROM dg_full.vmeta_property_hsat h
          WHERE 1 = 1 AND (h.property_type_src_id = ANY (ARRAY[5, 6]))) o ON o.schema_src_id::text = n.routine_schema::text AND o.object_src_id::text = n.routine_name::text
  WHERE 1 = 1 AND (o.schema_src_id IS NULL OR n.routine_name IS NULL);


-- dg_full.vmeta_list_attr_wo_screen_link source

CREATE OR REPLACE VIEW dg_full.vmeta_list_attr_wo_screen_link
AS WITH temp_sch_tbl_atr AS (
         SELECT pgn.nspname::text AS "T-schema",
            pgc.relname::text AS "T-name",
            pgc.oid AS "T-num",
                CASE pgc.relkind
                    WHEN 'r'::"char" THEN 'TABLE'::text
                    WHEN 'p'::"char" THEN 'TABLE'::text
                    WHEN 'v'::"char" THEN 'VIEW'::text
                    WHEN 'm'::"char" THEN 'VIEW'::text
                    ELSE NULL::text
                END AS "typeTable",
            a.attname::text AS "T-col-name",
            a.attnum::integer AS "T-col-num",
            format_type(a.atttypid, a.atttypmod) AS "T-col-type",
            col_description(pgc.oid, a.attnum::integer) AS "T-col-note"
           FROM pg_attribute a
             JOIN pg_class pgc ON a.attrelid = pgc.oid
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
          WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND a.attnum > 0 AND NOT a.attisdropped AND (pgn.nspname::text <> ALL (ARRAY['s_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text, 's_grnplm_as_cib_gm_dv'::text, 's_grnplm_as_cib_gm_ods_spod_udlprod'::text])) AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        ), temp_sch_tbl AS (
         SELECT pgn.nspname::text AS "T-schema",
            pgc.relname::text AS "T-name",
            pgc.oid AS "T-num",
                CASE pgc.relkind
                    WHEN 'r'::"char" THEN 'TABLE'::text
                    WHEN 'p'::"char" THEN 'TABLE'::text
                    WHEN 'v'::"char" THEN 'VIEW'::text
                    WHEN 'm'::"char" THEN 'VIEW'::text
                    ELSE NULL::text
                END AS "typeTable"
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
          WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND (pgn.nspname::text <> ALL (ARRAY['s_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text, 's_grnplm_as_cib_gm_dv'::text, 's_grnplm_as_cib_gm_ods_spod_udlprod'::text])) AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        ), ttt AS (
         SELECT t."T-schema",
            t."T-name",
            t."T-num",
            t."typeTable",
            t."T-col-name",
            t."T-col-num",
            t."T-col-type",
            t."T-col-note",
            o.object_id,
            o.object_group_id
           FROM temp_sch_tbl_atr t
             LEFT JOIN dg_full.meta_object_ref_table o ON t."T-schema" = o.schema_src_id::text AND t."T-name" = o.table_src_id::text AND t."T-col-name" = o.attribute_src_id
          WHERE 1 = 1
          GROUP BY t."T-schema", t."T-name", t."T-num", t."typeTable", t."T-col-name", t."T-col-num", t."T-col-type", t."T-col-note", o.object_id, o.object_group_id
        UNION ALL
         SELECT t."T-schema",
            t."T-name",
            t."T-num",
            t."typeTable",
            NULL::text AS "T-col-name",
            NULL::integer AS "T-col-num",
            NULL::text AS "T-col-type",
            NULL::text AS "T-col-note",
            o.object_id,
            o.object_group_id
           FROM temp_sch_tbl t
             LEFT JOIN dg_full.meta_object_ref_table o ON t."T-schema" = o.schema_src_id::text AND t."T-name" = o.table_src_id::text AND o.attribute_src_id IS NULL
          WHERE 1 = 1
          GROUP BY t."T-schema", t."T-name", t."T-num", t."typeTable", NULL::text, NULL::integer, o.object_id, o.object_group_id
        )
 SELECT ttt."T-schema",
    ttt."T-name",
    ttt."T-num",
    ttt."typeTable",
    ttt."T-col-name",
    ttt."T-col-num",
    ttt."T-col-type",
    ttt."T-col-note",
    ttt.object_id,
    sum(
        CASE
            WHEN l.screen_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END) AS screen_link_cnt
   FROM ttt
     LEFT JOIN dg_full.meta_screen_link l ON ttt.object_group_id = l.object_group_id
  GROUP BY ttt."T-schema", ttt."T-name", ttt."T-num", ttt."typeTable", ttt."T-col-name", ttt."T-col-num", ttt."T-col-type", ttt."T-col-note", ttt.object_id;


-- dg_full.vmeta_node_ctl_status_from_jira source

CREATE OR REPLACE VIEW dg_full.vmeta_node_ctl_status_from_jira
AS WITH ctl_wf_stts AS (
         SELECT j.id,
            j.description,
            j.summary,
            j.created,
            j.resolutiondate,
            j.issuenum,
                CASE
                    WHEN j.summary::text ~~* '[ПКАП ГР]%Остановка потока на ПРОМ'::text OR j.summary::text ~~* '[ПКАП ГР]%Снять поток с автозапуска ПРОМ'::text THEN 'stop'::text
                    WHEN j.summary::text ~~* '[ПКАП ГР]%Запуск поток% на ПРОМ%'::text THEN 'start'::text
                    ELSE 'other'::text
                END AS run_status,
            iss.pname
           FROM s_grnplm_as_cib_gm_stg_espd.jira_project p
             JOIN s_grnplm_as_cib_gm_stg_espd.jira_jiraissue j ON p.id::text = j.project::text
             JOIN s_grnplm_as_cib_gm_stg_espd.jira_issuestatus iss ON j.issuestatus::text = iss.id::text AND (iss.pname::text <> ALL (ARRAY['Cancelled'::character varying::text, 'Open'::character varying::text, 'Backlog'::character varying::text, 'In Progress'::character varying::text, 'To Do'::character varying::text, 'Need Info'::character varying::text]))
          WHERE p.pkey::text = 'DOTIB'::text AND j.summary::text ~~* '[ПКАП ГР]%ПРОМ%'::text AND j.summary::text !~~ '[ПКАП ГР] Запрос информации с ПРОМа'::text
          ORDER BY j.resolutiondate DESC
        ), wf0 AS (
         SELECT n.schema_src_id,
            n.node_src_id,
            n.node_cd,
            n.is_active,
            n.node_type_src_id,
            n.node_type_cd,
            s_1.id
           FROM dg_full.meta_node_ref_table n
             LEFT JOIN ctl_wf_stts s_1 ON s_1.description::text ~~* (('%'::text || n.schema_src_id::text) || '%'::text) AND s_1.description::text ~~* (('%'::text || n.node_src_id::text) || '%'::text)
          WHERE n.src_cd::text = 'CTL'::text AND n.node_type_src_id = 5
        ), wf1 AS (
         SELECT wf0.schema_src_id,
            wf0.node_src_id,
            wf0.node_cd,
            wf0.is_active,
            wf0.node_type_src_id,
            wf0.node_type_cd,
            max(wf0.id::text) AS last_id
           FROM wf0
          GROUP BY wf0.schema_src_id, wf0.node_src_id, wf0.node_cd, wf0.is_active, wf0.node_type_src_id, wf0.node_type_cd
        ), wf2 AS (
         SELECT wf1.schema_src_id,
            wf1.node_src_id,
            wf1.node_type_cd,
            wf1.is_active,
            wf1.last_id
           FROM wf1
             JOIN ctl_wf_stts s_1 ON wf1.last_id = s_1.id::text
        UNION ALL
         SELECT COALESCE(e.target_schema_src_id, wf1.schema_src_id) AS schema_src_id,
            COALESCE(e.target_node_src_id, wf1.node_src_id) AS node_src_id,
            COALESCE(e.tgt_node_type_cd, wf1.node_type_cd::text) AS node_type_cd,
            COALESCE(e.is_active, wf1.is_active) AS is_active,
            wf1.last_id
           FROM wf1
             JOIN dg_full.meta_edge_link e ON wf1.schema_src_id::text = e.src_schema_src_id::text AND wf1.node_src_id::text = e.src_node_src_id::text AND wf1.node_type_cd::text = e.src_node_type_cd
          WHERE 1 = 1 AND e.tgt_node_type_cd = 'Table'::text
        )
 SELECT wf2.schema_src_id,
    wf2.node_src_id,
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
   FROM wf2
     LEFT JOIN ctl_wf_stts s ON wf2.last_id = s.id::text
  GROUP BY wf2.schema_src_id, wf2.node_src_id, wf2.node_type_cd, wf2.is_active, s.id, s.description, s.summary, s.created, s.resolutiondate, s.issuenum, s.run_status, s.pname;


-- dg_full.vmeta_object_group_ref_table source

CREATE OR REPLACE VIEW dg_full.vmeta_object_group_ref_table
AS SELECT m.object_group_id,
    m.object_group_name,
    m.object_group_descr,
    m.load_dttm,
    m.wf_load_id,
    m.src_cd,
    m.is_active,
    m.object_group_type
   FROM dg_full.meta_object_group_ref_table_manual m
UNION
 SELECT l.object_group_id,
    l.object_group_name,
    l.object_group_descr,
    l.load_dttm,
    l.wf_load_id,
    l.src_cd,
    l.is_active,
    l.object_group_type
   FROM dg_full.meta_object_group_ref_table l;


-- dg_full.vmeta_object_ref_table source

CREATE OR REPLACE VIEW dg_full.vmeta_object_ref_table
AS SELECT m.object_id,
    m.schema_src_id,
    m.table_src_id,
    m.attribute_src_id,
    m.attribute_type,
    m.object_order,
    m.is_active,
    m.load_dttm,
    m.wf_load_id,
    m.src_cd,
    m.node_type_src_id,
    m.object_group_id,
    m.object_alias
   FROM dg_full.meta_object_ref_table_manual m
UNION
 SELECT l.object_id,
    l.schema_src_id,
    l.table_src_id,
    l.attribute_src_id,
    l.attribute_type,
    l.object_order,
    l.is_active,
    l.load_dttm,
    l.wf_load_id,
    l.src_cd,
    l.node_type_src_id,
    l.object_group_id,
    l.object_alias
   FROM dg_full.meta_object_ref_table l;


-- dg_full.vmeta_operations_statistic source

CREATE OR REPLACE VIEW dg_full.vmeta_operations_statistic
AS WITH days10 AS (
         SELECT ts_report.ts_report::date AS start_dt
           FROM generate_series((now()::date - '10 days'::interval)::date::timestamp with time zone, now()::date::timestamp with time zone, '1 day'::interval) ts_report(ts_report)
        ), tbl_list AS (
         SELECT d.start_dt,
            pgn.nspname::text AS schema_src_id,
            pgc.relname::text AS table_src_id
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN s_grnplm_as_cib_gm_dg.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
             CROSS JOIN days10 d
          WHERE 1 = 1 AND pgn.nspname::text !~~ '%_stg_%'::text AND (pgn.nspname::text <> ALL (ARRAY['s_grnplm_as_cib_gm_ods_internal_eks_ibs'::text, 's_grnplm_as_cib_gm_stg_espd'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text, 's_grnplm_as_cib_gm_ods_spod_udlprod'::text, 's_grnplm_as_cib_gm_dv'::text])) AND pgc.relname !~~ '%_prt_%'::text AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char"]))
          GROUP BY d.start_dt, pgn.nspname::text, pgc.relname::text, pgc.relkind
        ), tbl_metrics AS (
         SELECT t1.created_at,
            t1.wf_id,
            t1.wf_loading_id,
            t1.value,
            t1.category,
            t1.nspname AS schema_src_id,
            t1.relname AS table_src_id,
            t1.name,
                CASE
                    WHEN t1.name = 'deleted'::text THEN 1
                    WHEN t1.name = 'updated'::text THEN 2
                    WHEN t1.name = 'inserted'::text THEN 3
                    ELSE 0
                END AS code,
            t1.labels #>> '{entity_id}'::text[] AS entity_id,
            COALESCE(t1.labels #>> '{mode}'::text[], 'initial'::text) AS m_mode
           FROM s_grnplm_as_cib_gm_meta.tibds_mertics t1
          WHERE 1 = 1 AND (t1.name = ANY (ARRAY['deleted'::text, 'inserted'::text, 'updated'::text]))
        UNION
         SELECT m_1.created_at,
            m_1.wf_id,
            m_1.wf_loading_id,
            m_1.value,
            m_1.category,
            m_1.nspname AS schema_src_id,
            m_1.relname AS table_src_id,
            m_1.name,
                CASE
                    WHEN m_1.name = 'deleted'::text THEN 1
                    WHEN m_1.name = 'updated'::text THEN 2
                    WHEN m_1.name = 'inserted'::text THEN 3
                    ELSE 0
                END AS code,
            m_1.labels #>> '{entity_id}'::text[] AS entity_id,
            m_1.labels #>> '{mode}'::text[] AS m_mode
           FROM s_grnplm_as_cib_gm_meta_core.metrics m_1
          WHERE 1 = 1 AND (m_1.name = ANY (ARRAY['deleted'::text, 'inserted'::text, 'updated'::text]))
        )
 SELECT l.start_dt,
    l.schema_src_id,
    l.table_src_id,
    m.wf_id,
    m.wf_loading_id,
    COALESCE(m.category, 'histogram'::text) AS m_category,
    COALESCE(m.name, 'inserted'::text) AS m_operation_nm,
    COALESCE(m.code, 3) AS m_operation_od,
    COALESCE(m.value, 0::numeric) AS value,
    m.entity_id,
    COALESCE(m.m_mode, 'initial'::text) AS m_mode,
    COALESCE(m.created_at, l.start_dt::timestamp without time zone) AS created_at,
    row_number() OVER (PARTITION BY l.start_dt, l.schema_src_id, l.table_src_id, m.wf_loading_id ORDER BY COALESCE(m.created_at, l.start_dt::timestamp without time zone), m.code) AS row_number
   FROM tbl_list l
     LEFT JOIN tbl_metrics m ON l.start_dt = m.created_at::date AND l.schema_src_id = m.schema_src_id AND l.table_src_id = m.table_src_id
  WHERE 1 = 1;


-- dg_full.vmeta_property_hsat source

CREATE OR REPLACE VIEW dg_full.vmeta_property_hsat
AS SELECT mph.property_id,
    mph.object_src_id,
    mph.schema_src_id,
    mph.edge_id,
    mph.load_dttm,
    mph.src_cd,
    mph.wf_load_id,
    mph.eff_from_dttm,
    mph.eff_to_dttm,
    mph.last_seen_dttm,
    mph.property_type_src_id,
    mph.property_val
   FROM dg_full.meta_property_hsat mph
UNION ALL
 SELECT m.property_id,
    m.object_src_id,
    m.schema_src_id,
    - 1::bigint AS edge_id,
    now() AS load_dttm,
    'GP'::text AS src_cd,
    - 1::bigint AS wf_load_id,
    '1999-01-01 00:00:00'::timestamp without time zone AS eff_from_dttm,
    '2999-12-31 00:00:00'::timestamp without time zone AS eff_to_dttm,
    now() AS last_seen_dttm,
    m.property_type_src_id,
    m.property_val
   FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_property_hsat m
  WHERE m.dl_file_id::bigint = (( SELECT max(m1.dl_file_id::bigint) AS max
           FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_property_hsat m1));


-- dg_full.vmeta_s2t_dq_csv source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_dq_csv
AS WITH tbl_list AS (
        (
                 SELECT pgn.nspname::text AS schema_src_id,
                    pgc.relname::text AS table_src_id,
                    a.attname::text AS attribute_src_id
                   FROM pg_attribute a
                     JOIN pg_class pgc ON a.attrelid = pgc.oid
                     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
                     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
                  WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND a.attnum > 0 AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
                           FROM pg_inherits i
                          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
                UNION ALL
                 SELECT pgn.nspname::text AS schema_src_id,
                    pgc.relname::text AS table_src_id,
                    NULL::text AS attribute_src_id
                   FROM pg_class pgc
                     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
                     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
                  WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        ) UNION
         SELECT p.schema_src_id,
            p.table_src_id,
            p.attribute_src_id
           FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p
          WHERE 1 = 1 AND ((p.dl_file_id::bigint, p.schema_src_id, p.table_src_id) IN ( SELECT max(p1.dl_file_id::bigint) AS max,
                    p1.schema_src_id,
                    p1.table_src_id
                   FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p1
                  GROUP BY p1.schema_src_id, p1.table_src_id))
        ), chk_list AS (
         SELECT p.schema_src_id,
            p.table_src_id,
            p.attribute_src_id,
            p.group_prc,
            p.prc_interval,
            p.prc_negative,
            p.prc_null,
            p.prc_unique,
            p.prc_zero,
            p.cnt_takes,
            p.last_recalc_date,
            p.monotony_break,
            p.cnt_rows,
            p.story_num
           FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p
          WHERE 1 = 1 AND ((p.dl_file_id::bigint, p.schema_src_id, p.table_src_id) IN ( SELECT max(p1.dl_file_id::bigint) AS max,
                    p1.schema_src_id,
                    p1.table_src_id
                   FROM s_grnplm_as_cib_gm_ods_spod_udlprod.meta_add_technical_kkd p1
                  GROUP BY p1.schema_src_id, p1.table_src_id))
        )
 SELECT t.schema_src_id,
    t.table_src_id,
    t.attribute_src_id,
    c.group_prc,
    c.prc_interval,
    c.prc_negative,
    c.prc_null,
    c.prc_unique,
    c.prc_zero,
    c.cnt_takes,
    c.last_recalc_date,
    c.monotony_break,
    c.cnt_rows,
    c.story_num
   FROM tbl_list t
     LEFT JOIN chk_list c ON t.schema_src_id = c.schema_src_id AND t.table_src_id = c.table_src_id AND COALESCE(t.attribute_src_id, '-'::text) = COALESCE(c.attribute_src_id, '-'::text);


-- dg_full.vmeta_s2t_dq_json source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_dq_json
AS WITH constraint_ AS (
         SELECT c.conrelid,
            c.conkey,
            c.contype,
            cols.colnum
           FROM pg_constraint c
             CROSS JOIN LATERAL unnest(c.conkey) cols(colnum)
          ORDER BY c.conrelid
        ), partition_ AS (
         SELECT p_1.parrelid,
            p_1.parlevel,
            p_1.paratts[i.i] AS attnum,
            i.i
           FROM pg_partition p_1,
            generate_series(0, ( SELECT max(array_upper(pg_partition.paratts, 1)) AS max
                   FROM pg_partition)) i(i)
          WHERE p_1.paratts[i.i] IS NOT NULL
        )
 SELECT pgn.nspname::text AS "T-schema",
    obj_description(pgn.oid) AS "T-schema-note",
    pgc.relname::text AS "T-name",
        CASE pgc.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'p'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'VIEW'::text
            ELSE NULL::text
        END AS "typeTable",
    obj_description(pgc.oid) AS "T-note",
    a.attname::text AS "T-col-name",
    format_type(a.atttypid, a.atttypmod) AS "T-col-type",
        CASE
            WHEN a.attnotnull IS TRUE THEN 'NOT NULL'::text
            ELSE 'NULL'::text
        END AS "T-col-null",
        CASE
            WHEN cp.conrelid IS NOT NULL THEN 'Y'::text
            ELSE 'N'::text
        END AS "T-col-pk",
        CASE
            WHEN cf.conrelid IS NOT NULL THEN 'Y'::text
            ELSE 'N'::text
        END AS "T-col-fk",
    col_description(pgc.oid, a.attnum::integer) AS "T-col-note",
        CASE
            WHEN p.parrelid IS NOT NULL THEN a.attname
            ELSE NULL::name
        END::text AS "codePartition",
    NULL::text AS "% interval",
    NULL::text AS "% zero",
    NULL::text AS "% negative",
    NULL::text AS "% unique",
    NULL::text AS "% null",
    NULL::text AS "Нарушение монотонности",
    NULL::text AS "Количество загруженных строк",
    NULL::text AS "Количество дублей по ключевым атр",
    NULL::text AS "Последняя расчетная дата",
    a.attrelid::bigint AS object_id,
    a.attrelid::bigint * 1000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
     LEFT JOIN constraint_ cp ON a.attrelid = cp.conrelid AND a.attnum = cp.colnum AND cp.contype = 'p'::"char"
     LEFT JOIN constraint_ cf ON a.attrelid = cf.conrelid AND a.attnum = cf.colnum AND cp.contype = 'f'::"char"
     LEFT JOIN partition_ p ON p.parrelid = pgc.oid AND p.attnum = a.attnum
  WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND a.attnum > 0 AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]));


-- dg_full.vmeta_s2t_meta_graph source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_meta_graph
AS WITH RECURSIVE search_graph(src_schema_src_id, src_node_src_id, target_schema_src_id, target_node_src_id, src_node_id, target_node_id, depth, path, cycle) AS (
         SELECT g.src_schema_src_id,
            g.src_node_src_id,
            g.target_schema_src_id,
            g.target_node_src_id,
            (g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text AS src_node_id,
            (g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text AS target_node_id,
            1 AS depth,
            ARRAY[(g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text, (g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text] AS path,
            false AS cycle,
            (g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text AS root_node_id
           FROM dg_full.vmeta_s2t_meta_s2t g
          WHERE 1 = 1 AND g.target_node_src_id::text <> ''::text
        UNION ALL
         SELECT g.src_schema_src_id,
            g.src_node_src_id,
            g.target_schema_src_id,
            g.target_node_src_id,
            (g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text AS src_node_id,
            (g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text AS target_node_id,
            sg.depth + 1 AS depth,
            sg.path || ((g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text),
            ((g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text) = ANY (sg.path),
            sg.root_node_id
           FROM dg_full.vmeta_s2t_meta_s2t g
             JOIN search_graph sg ON g.target_node_id = sg.src_node_id
          WHERE 1 = 1 AND NOT sg.cycle
        ), temp_sql AS (
         SELECT sg.src_schema_src_id,
            sg.src_node_src_id,
            sg.target_schema_src_id,
            sg.target_node_src_id,
            sg.src_node_id,
            sg.target_node_id,
            sg.depth,
            sg.path,
            sg.cycle,
            sg.root_node_id
           FROM search_graph sg
          GROUP BY sg.src_schema_src_id, sg.src_node_src_id, sg.target_schema_src_id, sg.target_node_src_id, sg.src_node_id, sg.target_node_id, sg.depth, sg.path, sg.cycle, sg.root_node_id
        ), temp_sql_2 AS (
         SELECT replace(replace(replace(temp_sql.src_node_id, '://'::text, '.'::text), '/'::text, '.'::text), ' '::text, '.'::text) AS node_id,
            temp_sql.depth,
            temp_sql.root_node_id
           FROM temp_sql
          GROUP BY replace(replace(replace(temp_sql.src_node_id, '://'::text, '.'::text), '/'::text, '.'::text), ' '::text, '.'::text), temp_sql.depth, temp_sql.root_node_id
        UNION
         SELECT replace(replace(replace(temp_sql.target_node_id, '://'::text, '.'::text), '/'::text, '.'::text), ' '::text, '.'::text) AS node_id,
            temp_sql.depth,
            temp_sql.root_node_id
           FROM temp_sql
          GROUP BY replace(replace(replace(temp_sql.target_node_id, '://'::text, '.'::text), '/'::text, '.'::text), ' '::text, '.'::text), temp_sql.depth, temp_sql.root_node_id
        )
 SELECT 'GREENPLUM'::text AS "T-trg-platform",
    'gp_gm1'::text AS "T-trg-instance",
    "substring"(temp_sql_2.root_node_id, 1, "position"(temp_sql_2.root_node_id, '.'::text) - 1) AS "T-trg-schema",
    "substring"(temp_sql_2.root_node_id, "position"(temp_sql_2.root_node_id, '.'::text) + 1) AS "T-trg",
    NULL::text AS "UserName",
    NULL::text AS "T-trg-f",
    NULL::text AS target_data_relevance,
    NULL::text AS target_data_hist,
    NULL::text AS target_data_freq,
    'GREENPLUM'::text AS "T-src-platform",
    'gp_gm1'::text AS "T-src-instance",
    "substring"(temp_sql_2.node_id, 1, "position"(temp_sql_2.node_id, '.'::text) - 1) AS "T-src-schema",
    "substring"(temp_sql_2.node_id, "position"(temp_sql_2.node_id, '.'::text) + 1) AS "T-src",
    NULL::text AS "T-src-main",
    NULL::text AS "T-src-f-name",
    NULL::text AS "T-src-f",
    NULL::text AS "T-src-join",
    NULL::text AS "T-src-join-on",
    NULL::text AS "T-src-where",
    NULL::text AS "T-src-group",
    NULL::text AS "T-k",
    NULL::text AS "T-hist-type",
    NULL::text AS "T-hist-role",
    NULL::text AS "codeDatamart",
    NULL::text AS "Datamart.description_source",
    NULL::text AS "Table.description_source",
    temp_sql_2.root_node_id
   FROM temp_sql_2
  WHERE 1 = 1 AND temp_sql_2.node_id <> temp_sql_2.root_node_id;


-- dg_full.vmeta_s2t_meta_list_objects source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_meta_list_objects
AS SELECT replace(bb.node_src_id::text, '"'::text, ''::text)::name AS node_src_id,
    bb.schema_src_id,
    bb.node_cd,
    bb.node_name,
    bb.node_type_src_id
   FROM ( SELECT pgc.relname AS node_src_id,
            pgn.nspname AS schema_src_id,
            pgc.relname AS node_cd,
            pgc.relname AS node_name,
                CASE pgc.relkind
                    WHEN 'r'::"char" THEN 'table'::text
                    WHEN 'v'::"char" THEN 'view'::text
                    WHEN 'm'::"char" THEN 'materialized view'::text
                    WHEN 'i'::"char" THEN 'index'::text
                    WHEN 'S'::"char" THEN 'sequence'::text
                    WHEN 's'::"char" THEN 'special'::text
                    WHEN 'f'::"char" THEN 'foreign table'::text
                    WHEN 'p'::"char" THEN 'partitioned table'::text
                    WHEN 'I'::"char" THEN 'partitioned index'::text
                    ELSE NULL::text
                END AS node_type_src_id
           FROM pg_class pgc
             JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_cd::name
          WHERE 1 = 1 AND NOT (EXISTS ( SELECT 1
                   FROM pg_inherits i
                  WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]))
        UNION
         SELECT pgp.proname AS node_src_id,
            pgn.nspname AS schema_src_id,
            pgp.proname AS node_cd,
            pgp.proname AS node_name,
            'proc'::text AS node_type_src_id
           FROM pg_proc pgp
             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
             JOIN dg_full.meta_schema_ref_table s ON pgn.nspname = s.schema_cd::name
          WHERE 1 = 1) bb;


-- dg_full.vmeta_s2t_meta_s2t source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_meta_s2t
AS SELECT bb.src_schema_src_id,
    bb.src_node_src_id::name AS src_node_src_id,
    bb.target_schema_src_id,
    bb.target_node_src_id::name AS target_node_src_id,
    bb.edge_type_src_id,
    ee.edge_type_cd,
    (bb.src_schema_src_id::text || '.'::text) || bb.src_node_src_id AS src_node_id,
    (bb.target_schema_src_id::text || '.'::text) || bb.target_node_src_id AS target_node_id
   FROM ( SELECT DISTINCT ns_src.nspname AS src_schema_src_id,
            replace(t.relname::text, '"'::text, ''::text) AS src_node_src_id,
            ns_tgt.nspname AS target_schema_src_id,
            replace(v.relname::text, '"'::text, ''::text) AS target_node_src_id,
            2 AS edge_type_src_id
           FROM pg_depend d
             JOIN pg_rewrite r ON r.oid = d.objid
             JOIN pg_class v ON v.oid = r.ev_class
             JOIN pg_namespace ns_tgt ON ns_tgt.oid = v.relnamespace
             JOIN pg_class t ON t.oid = d.refobjid
             JOIN pg_namespace ns_src ON ns_src.oid = t.relnamespace
          WHERE 1 = 1 AND (v.relkind = ANY (ARRAY['v'::"char", 'm'::"char", 'f'::"char"])) AND d.classid = 'pg_rewrite'::regclass::oid AND (d.refclassid = 'pg_class'::regclass::oid OR d.refclassid = 'pg_proc'::regclass::oid) AND NOT v.oid = d.refobjid AND ns_src.nspname <> 'pg_catalog'::name AND ns_tgt.nspname <> 'pg_catalog'::name
          GROUP BY ns_src.nspname, t.relname, ns_tgt.nspname, v.relname
        UNION ALL
         SELECT DISTINCT
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.nspname
                    ELSE tt.schema_src_id
                END AS src_schema_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.proname
                    ELSE tt.node_src_id
                END AS src_node_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.schema_src_id
                    ELSE tt.nspname
                END AS target_schema_src_id,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.node_src_id
                    ELSE tt.proname
                END AS target_node_src_id,
            COALESCE(tt.ww5, tt.ww51, tt.ww4) AS edge_type_src_id
           FROM ( SELECT t.schema_src_id,
                    replace(t.node_src_id::text, '"'::text, ''::text) AS node_src_id,
                    p.nspname,
                    replace(p.proname::text, '"'::text, ''::text) AS proname,
                    p.prosrc,
                        CASE
                            WHEN lower(p.prosrc) ~* ((('insert into '::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) THEN 5
                            ELSE NULL::integer
                        END AS ww5,
                        CASE
                            WHEN lower(p.prosrc) ~* (('v_tgt_table_name text default '''::text || t.node_src_id::text) || ';'''::text) THEN 5
                            ELSE NULL::integer
                        END AS ww51,
                        CASE
                            WHEN lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || ' %'::text) OR lower(p.prosrc) ~~ (((('%'::text || t.schema_src_id::text) || '.'::text) || t.node_src_id::text) || '(%'::text) THEN 4
                            ELSE NULL::integer
                        END AS ww4
                   FROM dg_full.vmeta_s2t_meta_list_objects t
                     CROSS JOIN ( SELECT (pgn.nspname::text || '.'::text) || pgp.proname::text AS target_node_id,
                            pgn.nspname,
                            pgp.proname,
                            replace(regexp_replace(btrim(pgp.prosrc), '[\n\r\t\v]+'::text, ''::text), '"'::text, ''::text) AS prosrc
                           FROM pg_proc pgp
                             JOIN pg_namespace pgn ON pgp.pronamespace = pgn.oid
                          WHERE 1 = 1
                          GROUP BY (pgn.nspname::text || '.'::text) || pgp.proname::text, pgn.nspname, pgp.proname, pgp.prosrc) p
                  WHERE 1 = 1 AND ((t.schema_src_id::text || '.'::text) || t.node_src_id::text) <> p.target_node_id) tt
          WHERE 1 = 1 AND (tt.ww4 IS NOT NULL OR tt.ww5 IS NOT NULL OR tt.ww51 IS NOT NULL) AND tt.nspname <> 'pg_catalog'::name AND tt.schema_src_id <> 'pg_catalog'::name
          GROUP BY
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.nspname
                    ELSE tt.schema_src_id
                END,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.proname
                    ELSE tt.node_src_id
                END,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.schema_src_id
                    ELSE tt.nspname
                END,
                CASE
                    WHEN COALESCE(tt.ww5, tt.ww51, tt.ww4) = 5 THEN tt.node_src_id
                    ELSE tt.proname
                END, COALESCE(tt.ww5, tt.ww51, tt.ww4)
        UNION ALL
         SELECT tt.src_node_src_id,
            tt.src_schema_src_id,
            tt.target_node_src_id,
            tt.target_schema_src_id,
            tt.edge_type_src_id
           FROM ( SELECT
                        CASE
                            WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || '(%'::text) THEN 6
                            WHEN etl.sql_line::text ~~ (((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) || ' %'::text) THEN 8
                            WHEN etl.sql_line::text ~~ ((('%'::text || src.schema_src_id::text) || '.'::text) || src.node_src_id::text) THEN 8
                            ELSE NULL::integer
                        END AS edge_type_src_id,
                    replace(src.node_src_id::text, '"'::text, ''::text) AS src_node_src_id,
                    src.schema_src_id AS src_schema_src_id,
                    replace(tgt.node_src_id::text, '"'::text, ''::text) AS target_node_src_id,
                    tgt.schema_src_id AS target_schema_src_id
                   FROM s_grnplm_as_cib_gm_meta.etl_bk9scn etl
                     JOIN dg_full.vmeta_s2t_meta_list_objects tgt ON etl.scenariocd::text = replace(tgt.node_src_id::text, '_'::text, ''::text)
                     CROSS JOIN dg_full.vmeta_s2t_meta_list_objects src
                  WHERE 1 = 1) tt
          WHERE tt.edge_type_src_id IS NOT NULL) bb
     JOIN dg_full.meta_edge_type_ref_table ee ON bb.edge_type_src_id = ee.edge_type_src_id;


-- dg_full.vmeta_s2t_meta_source_columns source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_meta_source_columns
AS SELECT g."T-src-platform" AS "T-platform",
    g."T-src-instance" AS "T-instance",
    g."T-src-schema" AS "T-schema",
    g."T-src" AS "T-name",
    a.attname::text AS "T-col-name",
    format_type(a.atttypid, a.atttypmod) AS "T-col-type",
    g.root_node_id
   FROM dg_full.vmeta_s2t_meta_graph g
     JOIN pg_class pgc ON pgc.relname::text = g."T-src"
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid AND pgn.nspname::text = g."T-src-schema"
     JOIN pg_attribute a ON a.attrelid = pgc.oid
  WHERE a.attnum > 0
  GROUP BY g."T-src-platform", g."T-src-instance", g."T-src-schema", g."T-src", a.attname::text, format_type(a.atttypid, a.atttypmod), g.root_node_id;


-- dg_full.vmeta_s2t_meta_target_columns source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_meta_target_columns
AS WITH constraint_ AS (
         SELECT c.conrelid,
            c.conkey,
            c.contype,
            cols.colnum
           FROM pg_constraint c
             CROSS JOIN LATERAL unnest(c.conkey) cols(colnum)
          ORDER BY c.conrelid
        ), partition_ AS (
         SELECT p_1.parrelid,
            p_1.parlevel,
            p_1.paratts[i.i] AS attnum,
            i.i
           FROM pg_partition p_1,
            generate_series(0, ( SELECT max(array_upper(pg_partition.paratts, 1)) AS max
                   FROM pg_partition)) i(i)
          WHERE p_1.paratts[i.i] IS NOT NULL
        )
 SELECT 'GREENPLUM'::text AS "T-platform",
    'capgp2'::text AS "T-instance",
    pgn.nspname::text AS "T-schema",
    obj_description(pgn.oid) AS "T-schema-note",
    pgc.relname::text AS "T-name",
    obj_description(pgc.oid) AS "T-note",
    a.attname::text AS "T-col-name",
    format_type(a.atttypid, a.atttypmod) AS "T-col-type",
        CASE
            WHEN a.attnotnull IS TRUE THEN 'NOT NULL'::text
            ELSE 'NULL'::text
        END AS "T-col-null",
        CASE
            WHEN cp.conrelid IS NOT NULL THEN 'Y'::text
            ELSE 'N'::text
        END AS "T-col-pk",
        CASE
            WHEN cf.conrelid IS NOT NULL THEN 'Y'::text
            ELSE 'N'::text
        END AS "T-col-fk",
    col_description(pgc.oid, a.attnum::integer) AS "T-col-note",
        CASE pgc.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'p'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'VIEW'::text
            ELSE NULL::text
        END AS "typeTable",
        CASE
            WHEN p.parrelid IS NOT NULL THEN a.attname
            ELSE NULL::name
        END::text AS "codePartition",
    NULL::text AS "namePartition",
    NULL::text AS "fieldOrder",
    NULL::text AS "sdsLocation",
    NULL::text AS "partitionFunc",
    NULL::text AS "partColExample",
    NULL::text AS "partColMask",
    NULL::text AS "isDate",
    NULL::text AS "isBusinessPart",
    (pgn.nspname::text || '.'::text) || pgc.relname::text AS root_node_id,
    a.attrelid::bigint AS object_id,
    a.attrelid::bigint * 1000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
     LEFT JOIN constraint_ cp ON a.attrelid = cp.conrelid AND a.attnum = cp.colnum AND cp.contype = 'p'::"char"
     LEFT JOIN constraint_ cf ON a.attrelid = cf.conrelid AND a.attnum = cf.colnum AND cp.contype = 'f'::"char"
     LEFT JOIN partition_ p ON p.parrelid = pgc.oid AND p.attnum = a.attnum
  WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND a.attnum > 0 AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]));


-- dg_full.vmeta_s2t_meta_target_columns_new source

CREATE OR REPLACE VIEW dg_full.vmeta_s2t_meta_target_columns_new
AS WITH constraint_ AS (
         SELECT c.conrelid,
            c.conkey,
            c.contype,
            cols.colnum
           FROM pg_constraint c
             CROSS JOIN LATERAL unnest(c.conkey) cols(colnum)
          ORDER BY c.conrelid
        ), partition_ AS (
         SELECT p_1.parrelid,
            p_1.parlevel,
            p_1.paratts[i.i] AS attnum,
            i.i
           FROM pg_partition p_1,
            generate_series(0, ( SELECT max(array_upper(pg_partition.paratts, 1)) AS max
                   FROM pg_partition)) i(i)
          WHERE p_1.paratts[i.i] IS NOT NULL
        )
 SELECT 'GREENPLUM'::text AS "T-platform",
    'gp_gm1'::text AS "T-instance",
    pgn.nspname::text AS "T-schema",
    obj_description(pgn.oid) AS "T-schema-note",
    pgc.relname::text AS "T-name",
    obj_description(pgc.oid) AS "T-note",
    a.attname::text AS "T-col-name",
    format_type(a.atttypid, a.atttypmod) AS "T-col-type",
        CASE
            WHEN a.attnotnull IS TRUE THEN 'NOT NULL'::text
            ELSE 'NULL'::text
        END AS "T-col-null",
        CASE
            WHEN cp.conrelid IS NOT NULL THEN 'Y'::text
            ELSE 'N'::text
        END AS "T-col-pk",
        CASE
            WHEN cf.conrelid IS NOT NULL THEN 'Y'::text
            ELSE 'N'::text
        END AS "T-col-fk",
    col_description(pgc.oid, a.attnum::integer) AS "T-col-note",
        CASE pgc.relkind
            WHEN 'r'::"char" THEN 'TABLE'::text
            WHEN 'p'::"char" THEN 'TABLE'::text
            WHEN 'v'::"char" THEN 'VIEW'::text
            WHEN 'm'::"char" THEN 'VIEW'::text
            ELSE NULL::text
        END AS "typeTable",
        CASE
            WHEN p.parrelid IS NOT NULL THEN a.attname
            ELSE NULL::name
        END::text AS "codePartition",
    NULL::text AS "namePartition",
    NULL::text AS "fieldOrder",
    NULL::text AS "sdsLocation",
    NULL::text AS "partitionFunc",
    NULL::text AS "partColExample",
    NULL::text AS "partColMask",
    NULL::text AS "isDate",
    NULL::text AS "isBusinessPart",
    (pgn.nspname::text || '.'::text) || pgc.relname::text AS root_node_id,
    a.attrelid::bigint AS object_id,
    a.attrelid::bigint * 1000 + a.attnum AS attr_id
   FROM pg_attribute a
     JOIN pg_class pgc ON a.attrelid = pgc.oid
     JOIN pg_namespace pgn ON pgc.relnamespace = pgn.oid
     JOIN dg_full.meta_schema_ref_table s ON s.schema_src_id::name = pgn.nspname
     LEFT JOIN constraint_ cp ON a.attrelid = cp.conrelid AND a.attnum = cp.colnum AND cp.contype = 'p'::"char"
     LEFT JOIN constraint_ cf ON a.attrelid = cf.conrelid AND a.attnum = cf.colnum AND cp.contype = 'f'::"char"
     LEFT JOIN partition_ p ON p.parrelid = pgc.oid AND p.attnum = a.attnum
  WHERE 1 = 1 AND pgc.relname !~~ '%_prt_%'::text AND a.attnum > 0 AND NOT a.attisdropped AND NOT (EXISTS ( SELECT 1
           FROM pg_inherits i
          WHERE i.inhrelid = pgc.oid)) AND (pgc.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'v'::"char", 'm'::"char"]));


-- dg_full.vmeta_scheduler_fact source

CREATE OR REPLACE VIEW dg_full.vmeta_scheduler_fact
AS WITH temp_now AS (
         SELECT max(d.processing_end_dttm) AS ctl_max
           FROM s_grnplm_as_cib_gm_meta_core.dsc_ctl_processing d
        ), temp_sever AS (
         SELECT f.load_dttm::date AS start_dt,
            f.schema_src_id,
            f.table_src_id,
            f.wf_load_id,
            sum(f.final_severity_score) AS severity
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
             CROSS JOIN temp_now n
          WHERE 1 = 1 AND f.load_dttm::date > date_trunc('month'::text, n.ctl_max)
          GROUP BY f.load_dttm::date, f.schema_src_id, f.table_src_id, f.wf_load_id
        ), temp_sever_max AS (
         SELECT tt.schema_src_id,
            tt.table_src_id,
            sum(tt.severity) AS severity_max
           FROM ( SELECT o.schema_src_id,
                    o.table_src_id,
                    l.screen_template_id,
                    max(p.priority_src_id) AS severity,
                    max(p.priority_src_id)::real / count(*)::real AS severity_cn
                   FROM dg_full.vmeta_screen_link l
                     JOIN dg_full.meta_screen_template_ref_table st ON l.screen_template_id = st.screen_template_id
                     JOIN dg_full.vmeta_object_ref_table o ON l.object_group_id = o.object_group_id AND o.attribute_src_id IS NULL
                     JOIN dg_full.meta_priority_ref_table p ON st.priority_cd = p.priority_cd
                  WHERE 1 = 1
                  GROUP BY o.schema_src_id, o.table_src_id, l.screen_template_id) tt
          GROUP BY tt.schema_src_id, tt.table_src_id
        ), temp_pr_7 AS (
         SELECT (h.schema_src_id::text || '||'::text) || h.object_src_id::text AS node_id,
            h.schema_src_id::text AS schema_src_id,
            h.object_src_id::text AS node_src_id,
            h.property_val
           FROM s_grnplm_as_cib_gm_dg.vmeta_property_hsat h
          WHERE 1 = 1 AND h.property_type_src_id = 7
        ), temp_pr_8 AS (
         SELECT (mel01.target_schema_src_id::text || '||'::text) || mel01.target_node_src_id::text AS root_node_id,
            mel01.target_schema_src_id AS root_schema_src_id,
            mel01.target_node_src_id AS root_node_src_id,
            mel01.tgt_node_type_cd AS root_node_type_cd,
            (h.schema_src_id || '||'::text) || h.node_src_id AS node_id,
            h.schema_src_id,
            h.node_src_id,
            h.node_type_cd
           FROM dg_full.meta_search_graph_target_all_obj h
             LEFT JOIN dg_full.meta_edge_link mel ON h.root_schema_src_id = mel.src_schema_src_id::text AND h.root_node_src_id = mel.src_node_src_id::text
             LEFT JOIN dg_full.meta_edge_link mel01 ON mel.target_schema_src_id::text = mel01.src_schema_src_id::text AND mel.target_node_src_id::text = mel01.src_node_src_id::text
          WHERE 1 = 1 AND h.root_node_type_cd::text = 'Flow'::text AND h.node_type_cd::text = 'Entity'::text AND mel.tgt_node_type_cd <> 'Entity'::text AND mel01.tgt_node_type_cd = 'Table'::text
        ), temp_plan AS (
         SELECT p.schema_src_id,
            p.node_src_id,
            p.scheduler_type_src_id,
            p.node_type_src_id,
            p.period_type_id,
            p.period_type_comment,
            p.period_refresh_comment,
            p.plan_,
            p.plan_next,
            p.pt_descr,
            p.every_times,
            p.plan_dt,
            p.plan_dt_next,
            p.plan_dt_prev,
            p.plan_prev,
            p.scheduler_id,
            p.src_cd,
            p.load_dttm,
            p.wf_load_id,
            p.eff_from_dttm,
            p.eff_to_dttm,
            p.last_seen_dttm,
            p.is_wf_time_sched_active,
            n.node_type_cd
           FROM dg_full.meta_scheduler_plan p
             JOIN dg_full.meta_node_type_ref_table n ON p.node_type_src_id = n.node_type_src_id
        ), link AS (
         SELECT DISTINCT olink.schema_src_id AS sch_name,
            olink.node_src_id AS tbl_name,
            olink.node_type_cd,
            olink.src_cd,
            sm.severity_max,
            m.severity,
            olink.depth,
            olink.root_node_id,
            olink.root_schema_src_id AS target_schema_src_id,
            olink.root_node_src_id AS target_node_src_id,
            smr.severity_max AS root_severity_max,
            mr.severity AS root_severity,
            tt.tbl_type,
            tt.max_dttm,
            tt.max_eff_from_dttm,
            tt.max_eff_to_dttm,
            ttr.max_dttm AS root_max_dttm,
            ttr.max_eff_from_dttm AS root_max_eff_from_dttm,
            ttr.max_eff_to_dttm AS root_max_eff_to_dttm,
            concat(to_char(n.ctl_max::timestamp with time zone - tt.max_eff_from_dttm::timestamp with time zone, 'DD'::text)::integer, 'd ', to_char(n.ctl_max::timestamp with time zone - tt.max_eff_from_dttm::timestamp with time zone, 'HH24'::text)::integer, 'h ', to_char(n.ctl_max::timestamp with time zone - tt.max_eff_from_dttm::timestamp with time zone, 'MI'::text)::integer, 'm') AS date_diff,
            ttr.tbl_type AS root_tbl_type,
            olink.root_node_type_cd,
            COALESCE(
                CASE
                    WHEN olink.root_is_active IS FALSE THEN 0
                    ELSE 1
                END, 0) + COALESCE(
                CASE
                    WHEN olink.is_active IS FALSE THEN 0
                    ELSE 1
                END, 0) AS is_active_objects,
            sr.period_type_comment,
            sr.period_refresh_comment,
                CASE
                    WHEN olink.root_is_active IS FALSE AND sr.period_refresh_comment ~~ 'Останов%'::text AND sr.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END AS is_active_root,
                CASE
                    WHEN olink.is_active IS FALSE AND s.period_refresh_comment ~~ 'Останов%'::text AND s.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END AS is_active,
            array_remove(array_agg(
                CASE
                    WHEN olink.node_type_cd::text = 'Function'::text THEN olink.node_id
                    ELSE NULL::text
                END), NULL::text) AS func_node_id,
                CASE
                    WHEN olink.node_type_cd::text <> 'Function'::text THEN olink.node_id
                    ELSE NULL::text
                END AS node_id,
            pr_7.property_val AS application_qs,
                CASE
                    WHEN pr_8.node_id IS NOT NULL THEN '*'::text
                    ELSE NULL::text
                END AS is_trigger,
            tt.err_stts_ods,
            tt.alive_ods,
            tt.status_log,
            tt.wf_loading_id,
            tt.wf_id,
            tt.stts_nm,
            tt.log,
            sh.plan_ AS plan_trg,
            sh.plan_prev AS plan_prev_trg,
            sh.plan_next AS plan_next_trg,
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END AS dd_diff,
            shr.plan_ AS root_plan_trg,
            shr.plan_prev AS root_plan_prev_trg,
            shr.plan_next AS root_plan_next_trg,
                CASE
                    WHEN shr.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, shr.plan_ - shr.plan_prev)
                    ELSE date_part('day'::text, shr.plan_next + '00:00:01'::interval - shr.plan_)
                END AS root_dd_diff,
            ttr.err_stts_ods AS root_err_stts_ods,
            ttr.alive_ods AS root_alive_ods,
            ttr.status_log AS root_status_log,
            ttr.wf_loading_id AS root_wf_loading_id,
            ttr.wf_id AS root_wf_id,
            ttr.stts_nm AS root_stts_nm,
            ttr.log AS root_log,
            array_remove(array_agg(olink.depth), NULL::integer) AS dpt
           FROM dg_full.meta_search_graph_target_all_obj olink
             CROSS JOIN temp_now n
             LEFT JOIN temp_plan sh ON olink.node_src_id = sh.node_src_id AND olink.schema_src_id = sh.schema_src_id AND olink.node_type_cd::text = sh.node_type_cd::text
             LEFT JOIN dg_full.vmeta_execute_fact tt ON olink.node_src_id = tt.tbl_name AND olink.schema_src_id = tt.sch_name AND tt.fl_max_fact_execute = 1 AND olink.node_type_cd::text = tt.node_type_cd::text
             LEFT JOIN temp_plan shr ON olink.root_node_src_id = shr.node_src_id AND olink.root_schema_src_id = shr.schema_src_id AND olink.root_node_type_cd::text = shr.node_type_cd::text
             LEFT JOIN dg_full.vmeta_execute_fact ttr ON olink.root_node_src_id = ttr.tbl_name AND olink.root_schema_src_id = ttr.sch_name AND ttr.fl_max_fact_execute = 1 AND olink.root_node_type_cd::text = ttr.node_type_cd::text
             LEFT JOIN dg_full.meta_scheduler_hsat sr ON sr.schema_src_id::text = olink.root_schema_src_id AND sr.node_src_id::text = olink.root_node_src_id AND sr.period_refresh_comment ~~ '%wf_event_sched%'::text
             LEFT JOIN dg_full.meta_scheduler_hsat s ON s.schema_src_id::text = olink.schema_src_id AND s.node_src_id::text = olink.node_src_id AND s.period_refresh_comment ~~ '%wf_event_sched%'::text
             LEFT JOIN temp_pr_7 pr_7 ON olink.root_node_src_id = pr_7.node_src_id AND olink.root_schema_src_id = pr_7.schema_src_id
             LEFT JOIN temp_pr_8 pr_8 ON olink.root_node_src_id = pr_8.root_node_src_id::text AND olink.root_schema_src_id = pr_8.root_schema_src_id::text AND olink.schema_src_id =
                CASE pr_8.schema_src_id
                    WHEN IS NOT DISTINCT FROM 'xx'::text THEN olink.schema_src_id
                    ELSE pr_8.schema_src_id
                END AND olink.node_src_id = pr_8.node_src_id
             LEFT JOIN temp_sever_max sm ON olink.schema_src_id = sm.schema_src_id::text AND olink.node_src_id = sm.table_src_id::text
             LEFT JOIN temp_sever_max smr ON olink.root_schema_src_id = smr.schema_src_id::text AND olink.root_node_src_id = smr.table_src_id::text
             LEFT JOIN temp_sever m ON olink.schema_src_id = m.schema_src_id::text AND olink.node_src_id = m.table_src_id::text AND m.start_dt = tt.max_dttm::date AND m.wf_load_id = tt.wf_loading_id
             LEFT JOIN temp_sever mr ON olink.root_schema_src_id = mr.schema_src_id::text AND olink.root_node_src_id = mr.table_src_id::text AND mr.start_dt = ttr.max_dttm::date AND mr.wf_load_id = ttr.wf_loading_id
          WHERE 1 = 1
          GROUP BY olink.schema_src_id, olink.node_src_id, olink.node_type_cd, olink.src_cd, sm.severity_max, m.severity, olink.depth, olink.root_node_id, olink.root_schema_src_id, olink.root_node_src_id, smr.severity_max, mr.severity, tt.tbl_type, tt.max_dttm, tt.max_eff_from_dttm, tt.max_eff_to_dttm, ttr.max_dttm, ttr.max_eff_from_dttm, ttr.max_eff_to_dttm, concat(to_char(n.ctl_max::timestamp with time zone - tt.max_eff_from_dttm::timestamp with time zone, 'DD'::text)::integer, 'd ', to_char(n.ctl_max::timestamp with time zone - tt.max_eff_from_dttm::timestamp with time zone, 'HH24'::text)::integer, 'h ', to_char(n.ctl_max::timestamp with time zone - tt.max_eff_from_dttm::timestamp with time zone, 'MI'::text)::integer, 'm'), ttr.tbl_type, olink.root_node_type_cd, COALESCE(
                CASE
                    WHEN olink.root_is_active IS FALSE THEN 0
                    ELSE 1
                END, 0) + COALESCE(
                CASE
                    WHEN olink.is_active IS FALSE THEN 0
                    ELSE 1
                END, 0), sr.period_type_comment, sr.period_refresh_comment,
                CASE
                    WHEN olink.root_is_active IS FALSE AND sr.period_refresh_comment ~~ 'Останов%'::text AND sr.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END,
                CASE
                    WHEN olink.is_active IS FALSE AND s.period_refresh_comment ~~ 'Останов%'::text AND s.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END,
                CASE
                    WHEN olink.node_type_cd::text <> 'Function'::text THEN olink.node_id
                    ELSE NULL::text
                END, pr_7.property_val,
                CASE
                    WHEN pr_8.node_id IS NOT NULL THEN '*'::text
                    ELSE NULL::text
                END, tt.err_stts_ods, tt.alive_ods, tt.status_log, tt.wf_loading_id, tt.wf_id, tt.stts_nm, tt.log, sh.plan_, sh.plan_prev, sh.plan_next,
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END, shr.plan_, shr.plan_prev, shr.plan_next,
                CASE
                    WHEN shr.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, shr.plan_ - shr.plan_prev)
                    ELSE date_part('day'::text, shr.plan_next + '00:00:01'::interval - shr.plan_)
                END, ttr.err_stts_ods, ttr.alive_ods, ttr.status_log, ttr.wf_loading_id, ttr.wf_id, ttr.stts_nm, ttr.log
        ), link1 AS (
         SELECT l.sch_name,
            l.tbl_name,
            l.node_type_cd,
            l.src_cd,
            l.severity_max,
            l.severity,
            l.depth,
            l.root_node_id,
            l.target_schema_src_id,
            l.target_node_src_id,
            l.root_severity_max,
            l.root_severity,
            l.tbl_type,
            l.max_dttm,
            l.max_eff_from_dttm,
            l.max_eff_to_dttm,
            l.root_max_dttm,
            l.root_max_eff_from_dttm,
            l.root_max_eff_to_dttm,
            l.date_diff,
            l.root_tbl_type,
            l.root_node_type_cd,
            l.is_active_objects,
            l.period_type_comment,
            l.period_refresh_comment,
            l.is_active_root,
            l.is_active,
            l.func_node_id,
            l.node_id,
            l.application_qs,
            l.is_trigger,
            l.err_stts_ods,
            l.alive_ods,
            l.status_log,
            l.wf_loading_id,
            l.wf_id,
            l.stts_nm,
            l.log,
            l.dd_diff,
            l.plan_trg,
            l.plan_next_trg,
            l.plan_prev_trg,
            l.plan_trg + '01:00:00'::interval AS hb1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '1 day'::interval
                    ELSE l.plan_trg + '01:00:00'::interval
                END AS b1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '2 days'::interval
                    ELSE l.plan_trg + '02:00:00'::interval
                END AS b2,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '3 days'::interval
                    ELSE l.plan_trg + '03:00:00'::interval
                END AS b3,
            l.root_err_stts_ods,
            l.root_alive_ods,
            l.root_status_log,
            l.root_wf_loading_id,
            l.root_wf_id,
            l.root_stts_nm,
            l.root_log,
            l.root_dd_diff,
            l.root_plan_trg,
            l.root_plan_next_trg,
            l.root_plan_prev_trg,
            l.root_plan_trg + '01:00:00'::interval AS rhb1,
                CASE
                    WHEN l.root_dd_diff > 3::double precision THEN l.root_plan_trg + '1 day'::interval
                    ELSE l.root_plan_trg + '01:00:00'::interval
                END AS rb1,
                CASE
                    WHEN l.root_dd_diff > 3::double precision THEN l.root_plan_trg + '2 days'::interval
                    ELSE l.root_plan_trg + '02:00:00'::interval
                END AS rb2,
                CASE
                    WHEN l.root_dd_diff > 3::double precision THEN l.root_plan_trg + '3 days'::interval
                    ELSE l.root_plan_trg + '03:00:00'::interval
                END AS rb3,
            l.dpt
           FROM link l
        ), win_ AS (
         SELECT w.sch_name,
            w.tbl_name,
            w.node_type_cd,
            w.src_cd,
            w.severity_max,
            w.severity,
            w.depth,
            w.root_node_id,
            w.target_schema_src_id,
            w.target_node_src_id,
            w.root_severity_max,
            w.root_severity,
            w.tbl_type,
            w.max_dttm,
            w.max_eff_from_dttm,
            w.max_eff_to_dttm,
            w.root_max_dttm,
            w.root_max_eff_from_dttm,
            w.root_max_eff_to_dttm,
            w.date_diff,
            w.root_tbl_type,
            w.root_node_type_cd,
            w.is_active_objects,
            w.period_type_comment,
            w.period_refresh_comment,
            w.is_active_root,
            w.is_active,
            w.func_node_id,
            w.node_id,
            w.application_qs,
            w.is_trigger,
            w.err_stts_ods,
            w.alive_ods,
            w.status_log,
            w.stts_nm,
            w.log,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_from_dttm::date >= w.plan_trg::date AND w.max_eff_from_dttm::date < w.plan_next_trg::date AND n.ctl_max::date >= w.plan_trg::date AND n.ctl_max::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_from_dttm::date = w.plan_trg::date AND w.max_eff_from_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_from_dttm >= w.b1 AND w.max_eff_from_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b2 AND w.max_eff_from_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b3 AND w.max_eff_from_dttm <= w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_from_dttm IS NULL AND n.ctl_max::date >= w.plan_trg::date AND n.ctl_max::date < w.plan_next_trg::date AND n.ctl_max::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END AS ready_str,
                CASE
                    WHEN w.max_eff_from_dttm < w.plan_trg THEN 0
                    WHEN w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm <= n.ctl_max THEN 1
                    WHEN w.max_eff_from_dttm >= n.ctl_max AND w.max_eff_from_dttm < w.plan_next_trg THEN 0
                    WHEN w.max_eff_from_dttm > w.plan_next_trg THEN 0
                    ELSE 0
                END AS ready_fl,
                CASE
                    WHEN w.is_active_root IS FALSE THEN 'gray'::text
                    WHEN w.root_max_eff_from_dttm::date >= w.root_plan_trg::date AND w.root_max_eff_from_dttm::date < w.root_plan_next_trg::date AND n.ctl_max::date >= w.root_plan_trg::date AND n.ctl_max::date <= w.root_plan_next_trg::date THEN
                    CASE
                        WHEN w.root_max_eff_from_dttm::date = w.root_plan_trg::date AND w.root_max_eff_from_dttm::time without time zone < w.root_plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.root_err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.root_max_eff_from_dttm >= w.root_plan_trg AND w.root_max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.root_max_eff_from_dttm >= w.rb1 AND w.root_max_eff_from_dttm <= w.rb2 THEN 'yellow'::text
                        WHEN w.root_max_eff_from_dttm >= w.rb2 AND w.root_max_eff_from_dttm <= w.rb3 THEN 'd yellow'::text
                        WHEN w.root_max_eff_from_dttm >= w.rb3 AND w.root_max_eff_from_dttm <= w.root_plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.root_max_eff_from_dttm IS NULL AND n.ctl_max::date >= w.root_plan_trg::date AND n.ctl_max::date <= w.root_plan_next_trg::date AND n.ctl_max::time without time zone > w.root_plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END AS root_ready_str,
                CASE
                    WHEN w.root_max_eff_from_dttm < w.root_plan_trg THEN 0
                    WHEN w.root_max_eff_from_dttm >= w.root_plan_trg AND w.root_max_eff_from_dttm <= n.ctl_max THEN 1
                    WHEN w.root_max_eff_from_dttm >= n.ctl_max AND w.root_max_eff_from_dttm < w.root_plan_next_trg THEN 0
                    WHEN w.root_max_eff_from_dttm > w.root_plan_next_trg THEN 0
                    ELSE 0
                END AS root_ready_fl,
            w.root_err_stts_ods,
            w.root_alive_ods,
            w.root_status_log,
            w.root_stts_nm,
            w.root_log,
            w.dpt,
            w.wf_loading_id,
            w.wf_id,
            w.root_wf_loading_id,
            w.root_wf_id
           FROM link1 w
             CROSS JOIN temp_now n
        )
 SELECT "Window".sch_name,
    "Window".tbl_name,
    "Window".tbl_type,
    "Window".node_type_cd,
    "Window".is_active_objects,
    "Window".depth,
    "Window".max_dttm,
    "Window".max_eff_from_dttm,
    "Window".max_eff_to_dttm,
    "Window".date_diff,
    "Window".root_schema_src_id,
    "Window".root_node_src_id,
    "Window".root_max_dttm,
    "Window".root_max_eff_from_dttm,
    "Window".root_max_eff_to_dttm,
    "Window".max_dttm_diff,
    "Window".root_tbl_type,
    "Window".root_node_type_cd,
    "Window".application_qs,
    "Window".period_type_comment,
    "Window".period_refresh_comment,
    "Window".func_node_id,
    "Window".node_id,
    "Window".ctl_entity_node_id,
    "Window".ctl_wf_node_id,
    "Window".dpt,
    min("Window".depth) OVER (PARTITION BY "Window".sch_name, "Window".tbl_name) AS min_depth,
    "Window".src_cd,
    "Window".is_trigger,
    "Window".severity_max,
    "Window".root_severity_max,
    "Window".severity,
    "Window".root_severity,
    "Window".ready_str,
    "Window".ready_fl,
    "Window".root_ready_str,
    "Window".root_ready_fl,
    "Window".err_stts_ods,
    "Window".alive_ods,
    "Window".status_log,
    "Window".root_err_stts_ods,
    "Window".root_alive_ods,
    "Window".root_status_log,
    "Window".wf_loading_id,
    "Window".wf_id,
    "Window".root_wf_loading_id,
    "Window".root_wf_id,
    "Window".severity_prc,
    "Window".root_severity_prc,
    "Window".stts_nm,
    "Window".log,
    "Window".root_stts_nm,
    "Window".root_log,
    "Window".node_name,
    "Window".root_node_name,
    "Window".is_active,
    "Window".is_active_root
   FROM ( SELECT DISTINCT mx.sch_name,
            mx.tbl_name,
            mx.tbl_type,
            mx.node_type_cd,
            mx.is_active_objects,
            mx.depth,
            mx.max_dttm,
            mx.max_eff_from_dttm,
            mx.max_eff_to_dttm,
            mx.date_diff,
            mx.target_schema_src_id AS root_schema_src_id,
            mx.target_node_src_id AS root_node_src_id,
            mx.root_max_dttm,
            mx.root_max_eff_from_dttm,
            mx.root_max_eff_to_dttm,
            mx.root_max_dttm - mx.max_dttm AS max_dttm_diff,
            mx.root_tbl_type,
            mx.root_node_type_cd,
            mx.application_qs,
            mx.period_type_comment,
            mx.period_refresh_comment,
            mx.func_node_id,
            mx.node_id,
            NULL::text AS ctl_entity_node_id,
            NULL::text AS ctl_wf_node_id,
            mx.dpt,
            mx.src_cd,
            mx.is_trigger,
            mx.severity_max,
            mx.root_severity_max,
            mx.severity,
            mx.root_severity,
            mx.ready_str,
            mx.ready_fl,
            mx.root_ready_str,
            mx.root_ready_fl,
            mx.err_stts_ods,
            mx.alive_ods,
            mx.status_log,
            mx.root_err_stts_ods,
            mx.root_alive_ods,
            mx.root_status_log,
            mx.wf_loading_id,
            mx.wf_id,
            mx.root_wf_loading_id,
            mx.root_wf_id,
            round((mx.severity / mx.severity_max::double precision * 100::double precision)::numeric, 2) AS severity_prc,
            round((mx.root_severity / mx.root_severity_max::double precision * 100::double precision)::numeric, 2) AS root_severity_prc,
            mx.stts_nm,
            mx.log,
            mx.root_stts_nm,
            mx.root_log,
            n.node_name,
            rn.node_name AS root_node_name,
            mx.is_active,
            mx.is_active_root
           FROM win_ mx
             LEFT JOIN dg_full.meta_node_ref_table n ON mx.sch_name = n.schema_src_id::text AND mx.tbl_name = n.node_src_id::text
             LEFT JOIN dg_full.meta_node_ref_table rn ON mx.sch_name = rn.schema_src_id::text AND mx.tbl_name = rn.node_src_id::text
          WHERE 1 = 1 AND ((mx.sch_name || '.'::text) || mx.tbl_name) <> ((mx.target_schema_src_id || '.'::text) || mx.target_node_src_id)
          GROUP BY mx.sch_name, mx.tbl_name, mx.tbl_type, mx.node_type_cd, mx.is_active_objects, mx.depth, mx.max_dttm, mx.max_eff_from_dttm, mx.max_eff_to_dttm, mx.date_diff, mx.target_schema_src_id, mx.target_node_src_id, mx.root_max_dttm, mx.root_max_eff_from_dttm, mx.root_max_eff_to_dttm, mx.root_max_dttm - mx.max_dttm, mx.root_tbl_type, mx.root_node_type_cd, mx.application_qs, mx.period_type_comment, mx.period_refresh_comment, mx.func_node_id, mx.node_id, mx.dpt, mx.src_cd, mx.is_trigger, mx.severity_max, mx.root_severity_max, mx.severity, mx.root_severity, mx.ready_str, mx.ready_fl, mx.root_ready_str, mx.root_ready_fl, mx.err_stts_ods, mx.alive_ods, mx.status_log, mx.root_err_stts_ods, mx.root_alive_ods, mx.root_status_log, mx.wf_loading_id, mx.wf_id, mx.root_wf_loading_id, mx.root_wf_id, mx.stts_nm, mx.log, mx.root_stts_nm, mx.root_log, n.node_name, rn.node_name, mx.is_active, mx.is_active_root) "Window"(sch_name, tbl_name, tbl_type, node_type_cd, is_active_objects, depth, max_dttm, max_eff_from_dttm, max_eff_to_dttm, date_diff, root_schema_src_id, root_node_src_id, root_max_dttm, root_max_eff_from_dttm, root_max_eff_to_dttm, max_dttm_diff, root_tbl_type, root_node_type_cd, application_qs, period_type_comment, period_refresh_comment, func_node_id, node_id, ctl_entity_node_id, ctl_wf_node_id, dpt, src_cd, is_trigger, severity_max, root_severity_max, severity, root_severity, ready_str, ready_fl, root_ready_str, root_ready_fl, err_stts_ods, alive_ods, status_log, root_err_stts_ods, root_alive_ods, root_status_log, wf_loading_id, wf_id, root_wf_loading_id, root_wf_id, severity_prc, root_severity_prc, stts_nm, log, root_stts_nm, root_log, node_name, root_node_name, is_active, is_active_root);


-- dg_full.vmeta_scheduler_loader source

CREATE OR REPLACE VIEW dg_full.vmeta_scheduler_loader
AS WITH dt AS (
         SELECT now() AS now_
        ), temp_sever AS (
         SELECT f.load_dttm::date AS start_dt,
            f.schema_src_id,
            f.table_src_id,
            sum(f.final_severity_score) AS severity
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
          WHERE 1 = 1 AND f.load_dttm::date > date_trunc('month'::text, now())
          GROUP BY f.load_dttm::date, f.schema_src_id, f.table_src_id
        ), temp_sever_max AS (
         SELECT tt.schema_src_id,
            tt.table_src_id,
            sum(tt.severity) AS severity_max
           FROM ( SELECT o.schema_src_id,
                    o.table_src_id,
                    l.screen_template_id,
                    max(p.priority_src_id) AS severity,
                    max(p.priority_src_id)::real / count(*)::real AS severity_cn
                   FROM dg_full.meta_screen_link l
                     JOIN dg_full.meta_screen_template_ref_table st ON l.screen_template_id = st.screen_template_id
                     JOIN dg_full.meta_object_ref_table o ON l.object_group_id = o.object_group_id AND o.attribute_src_id IS NULL
                     JOIN dg_full.meta_priority_ref_table p ON st.priority_cd = p.priority_cd
                  WHERE 1 = 1 AND (l.screen_template_id = ANY (ARRAY[10011, 11, 10003, 3, 10001, 1, 10002, 2, 10004, 4, 10074, 87, 10078, 10014, 13, 10073, 73]))
                  GROUP BY o.schema_src_id, o.table_src_id, l.screen_template_id) tt
          GROUP BY tt.schema_src_id, tt.table_src_id
        ), temp_pr_7 AS (
         SELECT (h.schema_src_id::text || '.'::text) || h.object_src_id::text AS node_id,
            h.schema_src_id::text AS schema_src_id,
            h.object_src_id::text AS node_src_id,
            h.property_val
           FROM s_grnplm_as_cib_gm_dg.vmeta_property_hsat h
          WHERE 1 = 1 AND h.property_type_src_id = 7
        ), wino AS (
         SELECT olink.node_id,
            olink.node_src_id,
            olink.schema_src_id,
            olink.node_type_cd,
            olink.src_cd,
            olink.depth,
            olink.root_node_id,
            olink.root_node_src_id,
            olink.root_schema_src_id,
            olink.root_node_type_cd,
            o.tbl_type,
            o.max_dttm,
            o.max_eff_from_dttm,
            o.max_eff_to_dttm,
            oroot.max_dttm AS root_max_dttm,
            oroot.max_eff_from_dttm AS root_max_eff_from_dttm,
            oroot.max_eff_to_dttm AS root_max_eff_to_dttm,
            now() - o.max_dttm::timestamp with time zone AS date_diff,
            oroot.tbl_type AS root_tbl_type,
            rsh.plan_ AS rsh_plan_,
            COALESCE(sh.plan_, rsh.plan_) AS sh_plan_,
            rsh.plan_next AS rsh_plan_next,
            COALESCE(sh.plan_next, rsh.plan_next) AS sh_plan_next,
            rsh.plan_dt AS rsh_plan_dt,
            COALESCE(sh.plan_dt, rsh.plan_dt) AS sh_plan_dt,
                CASE
                    WHEN now()::date = COALESCE(sh.plan_dt, rsh.plan_dt) AND olink.schema_src_id !~~ '%_stg_%'::text AND olink.schema_src_id !~~ '%_espd_%'::text AND olink.schema_src_id !~~ '%_udlprod'::text THEN 1
                    ELSE 0
                END AS fl_stg,
            m.severity,
            sm.severity_max
           FROM s_grnplm_as_cib_gm_mart_dg.meta_search_graph_target_all_obj olink
             LEFT JOIN dg_full.vmeta_execute_fact o ON olink.node_src_id = o.tbl_name AND olink.schema_src_id = o.sch_name AND o.max_dttm::date = now()::date
             LEFT JOIN s_grnplm_as_cib_gm_dg.meta_scheduler_plan sh ON olink.node_src_id = sh.node_src_id AND olink.schema_src_id = sh.schema_src_id AND sh.plan_::date >= COALESCE(o.max_eff_from_dttm::date, now()::date) AND sh.plan_::date <= COALESCE(o.max_eff_to_dttm::date, now()::date)
             LEFT JOIN dg_full.vmeta_execute_fact oroot ON olink.root_node_src_id = oroot.tbl_name AND olink.root_schema_src_id = oroot.sch_name AND oroot.max_dttm::date = now()::date
             LEFT JOIN s_grnplm_as_cib_gm_dg.meta_scheduler_plan rsh ON olink.root_node_src_id = rsh.node_src_id AND olink.root_schema_src_id = rsh.schema_src_id AND rsh.plan_::date >= COALESCE(oroot.max_eff_from_dttm::date, now()::date) AND rsh.plan_::date <= COALESCE(oroot.max_eff_to_dttm::date, now()::date)
             LEFT JOIN temp_pr_7 p ON p.node_src_id = sh.node_src_id AND p.schema_src_id = sh.schema_src_id
             LEFT JOIN temp_pr_7 pr ON pr.node_src_id = rsh.node_src_id AND pr.schema_src_id = rsh.schema_src_id
             LEFT JOIN temp_sever m ON m.schema_src_id::text = olink.root_schema_src_id AND m.table_src_id::text = olink.root_node_src_id AND m.start_dt = oroot.max_dttm::date
             LEFT JOIN temp_sever_max sm ON sm.schema_src_id::text = olink.root_schema_src_id AND sm.table_src_id::text = olink.root_node_src_id
          WHERE 1 = 1 AND olink.node_type_cd::text = 'Table'::text AND (olink.root_node_type_cd::text = ANY (ARRAY['View'::character varying::text, 'Table'::character varying::text]))
          GROUP BY olink.node_id, olink.node_src_id, olink.schema_src_id, olink.node_type_cd, olink.src_cd, olink.depth, olink.root_node_id, olink.root_node_src_id, olink.root_schema_src_id, olink.root_node_type_cd, o.tbl_type, o.max_dttm, o.max_eff_from_dttm, o.max_eff_to_dttm, oroot.max_dttm, oroot.max_eff_from_dttm, oroot.max_eff_to_dttm, now() - o.max_dttm::timestamp with time zone, oroot.tbl_type, rsh.plan_, COALESCE(sh.plan_, rsh.plan_), rsh.plan_next, COALESCE(sh.plan_next, rsh.plan_next), rsh.plan_dt, COALESCE(sh.plan_dt, rsh.plan_dt),
                CASE
                    WHEN now()::date = COALESCE(sh.plan_dt, rsh.plan_dt) AND olink.schema_src_id !~~ '%_stg_%'::text AND olink.schema_src_id !~~ '%_espd_%'::text AND olink.schema_src_id !~~ '%_udlprod'::text THEN 1
                    ELSE 0
                END, m.severity, sm.severity_max
        ), link AS (
         SELECT wino.node_id,
            wino.schema_src_id,
            wino.node_src_id,
            wino.tbl_type,
            wino.node_type_cd,
            wino.src_cd,
            wino.depth,
            min(
                CASE
                    WHEN wino.node_type_cd::text = 'Function'::text THEN NULL::integer
                    ELSE wino.depth
                END) OVER (PARTITION BY wino.root_node_id) AS min_depth,
            wino.max_dttm,
            wino.max_eff_from_dttm,
            wino.max_eff_to_dttm,
            wino.date_diff,
            wino.root_node_id,
            wino.root_schema_src_id,
            wino.root_node_src_id,
            wino.root_tbl_type,
            wino.root_node_type_cd,
            wino.root_max_dttm,
            wino.root_max_eff_from_dttm,
            wino.root_max_eff_to_dttm,
            now() - wino.root_max_dttm::timestamp with time zone AS root_date_diff,
                CASE
                    WHEN wino.root_node_type_cd::text = 'Table'::text THEN wino.root_max_eff_from_dttm
                    WHEN wino.root_node_type_cd::text = 'View'::text AND wino.node_type_cd::text = 'Table'::text THEN wino.max_eff_from_dttm
                    ELSE NULL::timestamp without time zone
                END AS fact_started,
                CASE
                    WHEN wino.root_node_type_cd::text = 'Table'::text THEN wino.root_max_eff_to_dttm
                    WHEN wino.root_node_type_cd::text = 'View'::text AND wino.node_type_cd::text = 'Table'::text THEN wino.max_eff_to_dttm
                    ELSE NULL::timestamp without time zone
                END AS fact_ended,
                CASE
                    WHEN wino.root_node_type_cd::text = 'Table'::text THEN (max(wino.rsh_plan_) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone
                    WHEN wino.root_node_type_cd::text = 'View'::text AND wino.node_type_cd::text = 'Table'::text THEN (max(wino.sh_plan_) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone
                    ELSE NULL::timestamp without time zone
                END AS plan_dt,
                CASE
                    WHEN wino.root_node_type_cd::text = 'Table'::text THEN (max(wino.rsh_plan_next) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone - '00:00:01'::interval
                    WHEN wino.root_node_type_cd::text = 'View'::text AND wino.node_type_cd::text = 'Table'::text THEN (max(wino.sh_plan_next) OVER (PARTITION BY wino.root_schema_src_id, wino.root_node_src_id))::date::timestamp without time zone - '00:00:01'::interval
                    ELSE NULL::timestamp without time zone
                END AS plan_next_dt,
            wino.fl_stg,
            wino.severity,
            wino.severity_max
           FROM wino
        ), link_0 AS (
         SELECT l.schema_src_id,
            l.node_src_id,
            l.node_type_cd,
            l.depth,
            l.min_depth,
            l.root_schema_src_id,
            l.root_node_src_id,
            l.root_node_type_cd,
            l.root_max_dttm,
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
                END AS fl_waited_today,
            l.severity,
            l.severity_max
           FROM link l
        ), st_1 AS (
         SELECT DISTINCT w1.root_schema_src_id,
            w1.root_node_src_id,
            w1.root_node_type_cd,
            max(w1.root_max_dttm) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS root_max_dttm,
            max(w1.fact_ended) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w1,
            sum(w1.fl_waited_today) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w2,
            sum(w1.fl_fact_today) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS w3,
            max(w1.severity) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS root_severity,
            max(w1.severity_max) OVER (PARTITION BY w1.root_schema_src_id, w1.root_node_src_id) AS root_severity_max
           FROM link_0 w1
        )
 SELECT s1.root_schema_src_id,
    s1.root_node_src_id,
        CASE s1.root_node_type_cd
            WHEN IS NOT DISTINCT FROM 'Table'::text THEN s1.root_max_dttm
            ELSE s1.w1
        END AS root_max_dttm,
        CASE
            WHEN s1.w2 = s1.w3 THEN
            CASE s1.root_node_type_cd
                WHEN IS NOT DISTINCT FROM 'Table'::text THEN s1.root_max_dttm
                ELSE s1.w1
            END
            ELSE NULL::timestamp without time zone
        END AS ready_max_dttm,
    NULL::text AS application_qs,
    NULL::bigint AS fl_stg,
    s1.root_severity,
    s1.root_severity_max
   FROM st_1 s1
  WHERE 1 = 1 AND s1.root_schema_src_id ~~ '%_as_cib_gm_%'::text AND (s1.root_schema_src_id <> ALL (ARRAY['s_grnplm_as_cib_gm_mart_dg'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_stg_espd'::text]))
  GROUP BY s1.root_schema_src_id, s1.root_node_src_id,
        CASE s1.root_node_type_cd
            WHEN IS NOT DISTINCT FROM 'Table'::text THEN s1.root_max_dttm
            ELSE s1.w1
        END,
        CASE
            WHEN s1.w2 = s1.w3 THEN
            CASE s1.root_node_type_cd
                WHEN IS NOT DISTINCT FROM 'Table'::text THEN s1.root_max_dttm
                ELSE s1.w1
            END
            ELSE NULL::timestamp without time zone
        END, s1.root_severity, s1.root_severity_max
  ORDER BY s1.root_schema_src_id, s1.root_node_src_id,
        CASE s1.root_node_type_cd
            WHEN IS NOT DISTINCT FROM 'Table'::text THEN s1.root_max_dttm
            ELSE s1.w1
        END DESC;


-- dg_full.vmeta_scheduler_plan_fact source

CREATE OR REPLACE VIEW dg_full.vmeta_scheduler_plan_fact
AS WITH temp_now AS (
         SELECT max(d.processing_end_dttm) AS ctl_max
           FROM s_grnplm_as_cib_gm_meta_core.dsc_ctl_processing d
        ), temp_sever AS (
         SELECT f.load_dttm::date AS start_dt,
            f.schema_src_id,
            f.table_src_id,
            f.wf_load_id,
            sum(COALESCE(f.final_severity_score, 0::double precision)) AS severity
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
             CROSS JOIN temp_now n
          WHERE 1 = 1 AND f.load_dttm::date > date_trunc('month'::text, n.ctl_max)
          GROUP BY f.load_dttm::date, f.schema_src_id, f.table_src_id, f.wf_load_id
        ), temp_sever_max AS (
         SELECT tt.schema_src_id,
            tt.table_src_id,
            sum(COALESCE(tt.severity, 0)) AS severity_max
           FROM ( SELECT o.schema_src_id,
                    o.table_src_id,
                    l.screen_template_id,
                    max(p.priority_src_id) AS severity,
                    max(p.priority_src_id)::real / count(*)::real AS severity_cn
                   FROM dg_full.vmeta_screen_link l
                     JOIN dg_full.meta_screen_template_ref_table st ON l.screen_template_id = st.screen_template_id
                     JOIN dg_full.vmeta_object_ref_table o ON l.object_group_id = o.object_group_id AND o.attribute_src_id IS NULL
                     JOIN dg_full.meta_priority_ref_table p ON st.priority_cd = p.priority_cd
                  WHERE 1 = 1
                  GROUP BY o.schema_src_id, o.table_src_id, l.screen_template_id) tt
          GROUP BY tt.schema_src_id, tt.table_src_id
        ), max_fact AS (
         SELECT f.sch_name,
            f.tbl_name,
            max(f.max_eff_to_dttm) AS max_fact_dttm
           FROM dg_full.vmeta_execute_fact f
          GROUP BY f.sch_name, f.tbl_name
        ), link AS (
         SELECT (sh.schema_src_id || '||'::text) || sh.node_src_id AS node_id,
            sh.schema_src_id,
            sh.node_src_id,
            nt.node_type_cd,
            sh.src_cd,
            1::bigint AS depth,
            pl.tbl_type,
            sh.scheduler_id,
            sh.scheduler_type_src_id,
            sh.node_type_src_id,
            sh.period_type_id,
            sh.every_times,
            sh.period_type_comment,
            sh.period_refresh_comment,
            COALESCE(pl.fl_max_fact_execute, 0) AS fl_max_fact_execute,
            0 AS fl_hour_fail,
            sh.is_wf_time_sched_active,
            pl.err_stts_stg,
            pl.err_stts_ods,
            pl.alive_ods,
            pl.status_log,
                CASE
                    WHEN (n.ctl_max::date - pl.max_eff_to_dttm::date) <> 1 THEN ''::text
                    WHEN n.ctl_max::time without time zone <= pl.avg_start_time::time without time zone THEN ''::text
                    ELSE '-'::text
                END AS znk,
                CASE
                    WHEN (pl.today_start + pl.avg_ods_duration + '00:15:00'::interval) < n.ctl_max::time without time zone::interval AND pl.max_eff_to_dttm IS NULL THEN 'Long Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) < '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL THEN 'Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) >= '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL AND n.ctl_max::time without time zone::interval < (pl.avg_start_time + pl.avg_ods_duration + '00:40:00'::interval) THEN 'Attention: Run > 20 min'::text
                    WHEN pl.max_eff_to_dttm::date = n.ctl_max::date THEN 'Ok'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) > n.ctl_max::date THEN 'Ok'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:30:00'::interval) THEN 'ERROR'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:15:00'::interval) THEN 'Attention'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND sh.plan_dt_next = n.ctl_max::date AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN 'TODAY'::text
                    WHEN sh.plan_dt_next IS NULL THEN 'TODAY'::text
                    WHEN pl.max_eff_to_dttm::date < n.ctl_max::date THEN '-'::text
                    ELSE '-'::text
                END AS status,
                CASE
                    WHEN n.ctl_max::date = COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN
                    CASE
                        WHEN n.ctl_max::time without time zone::interval <= pl.avg_start_time THEN (pl.avg_start_time - n.ctl_max::time without time zone::interval)::time without time zone
                        ELSE n.ctl_max::time without time zone - pl.avg_start_time
                    END
                    ELSE '00:00:00'::time without time zone
                END::text AS time_before_start,
            pl.wf_loading_id,
            pl.stts_nm,
            pl.log,
            pl.wf_id,
            n.ctl_max AS now_,
            sh.plan_,
            sh.plan_next,
            sh.plan_dt,
            sh.plan_dt_next AS date_plan_next,
            sh.plan_prev AS plan_prev_trg,
            sh.plan_ AS plan_trg,
            sh.plan_next AS plan_next_trg,
            pl.max_dttm,
            pl.max_eff_from_dttm,
            pl.max_eff_to_dttm,
            age(sh.plan_ + '00:00:01'::interval,
                CASE
                    WHEN sh.plan_prev::date = '1900-01-01'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_prev
                END) AS plan_prev_plan_,
            age(
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_next
                END, sh.plan_ - '00:00:01'::interval) AS plan_plan_next,
            age(sh.plan_::timestamp with time zone, pl.max_eff_from_dttm::timestamp with time zone) AS plan_fact_diff,
            age(n.ctl_max::date::timestamp with time zone, pl.max_eff_to_dttm::date::timestamp with time zone) AS diff_day,
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END AS dd_diff,
            nod.is_active
           FROM dg_full.meta_scheduler_plan sh
             CROSS JOIN temp_now n
             JOIN dg_full.meta_node_type_ref_table nt ON sh.node_type_src_id = nt.node_type_src_id
             LEFT JOIN dg_full.vmeta_execute_fact pl ON sh.node_src_id = pl.tbl_name AND sh.schema_src_id = pl.sch_name AND sh.node_type_src_id = pl.node_type_src_id AND pl.max_eff_from_dttm::date >= sh.plan_::date AND pl.max_eff_from_dttm::date < sh.plan_next::date AND (pl.stts_nm <> ALL (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]))
             LEFT JOIN dg_full.meta_node_ref_table nod ON sh.schema_src_id = nod.schema_src_id::text AND sh.node_src_id = nod.node_src_id::text AND sh.node_type_src_id = nod.node_type_src_id
          WHERE 1 = 1 AND sh.schema_src_id !~~ '%_stg_%'::text
          GROUP BY (sh.schema_src_id || '||'::text) || sh.node_src_id, sh.schema_src_id, sh.node_src_id, nt.node_type_cd, sh.src_cd, 1::bigint, pl.tbl_type, sh.scheduler_id, sh.scheduler_type_src_id, sh.node_type_src_id, sh.period_type_id, sh.every_times, sh.period_type_comment, sh.period_refresh_comment, COALESCE(pl.fl_max_fact_execute, 0), 0::integer, sh.is_wf_time_sched_active, pl.err_stts_stg, pl.err_stts_ods, pl.alive_ods, pl.status_log,
                CASE
                    WHEN (n.ctl_max::date - pl.max_eff_to_dttm::date) <> 1 THEN ''::text
                    WHEN n.ctl_max::time without time zone <= pl.avg_start_time::time without time zone THEN ''::text
                    ELSE '-'::text
                END,
                CASE
                    WHEN (pl.today_start + pl.avg_ods_duration + '00:15:00'::interval) < n.ctl_max::time without time zone::interval AND pl.max_eff_to_dttm IS NULL THEN 'Long Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) < '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL THEN 'Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) >= '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL AND n.ctl_max::time without time zone::interval < (pl.avg_start_time + pl.avg_ods_duration + '00:40:00'::interval) THEN 'Attention: Run > 20 min'::text
                    WHEN pl.max_eff_to_dttm::date = n.ctl_max::date THEN 'Ok'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) > n.ctl_max::date THEN 'Ok'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:30:00'::interval) THEN 'ERROR'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:15:00'::interval) THEN 'Attention'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND sh.plan_dt_next = n.ctl_max::date AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN 'TODAY'::text
                    WHEN sh.plan_dt_next IS NULL THEN 'TODAY'::text
                    WHEN pl.max_eff_to_dttm::date < n.ctl_max::date THEN '-'::text
                    ELSE '-'::text
                END,
                CASE
                    WHEN n.ctl_max::date = COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN
                    CASE
                        WHEN n.ctl_max::time without time zone::interval <= pl.avg_start_time THEN (pl.avg_start_time - n.ctl_max::time without time zone::interval)::time without time zone
                        ELSE n.ctl_max::time without time zone - pl.avg_start_time
                    END
                    ELSE '00:00:00'::time without time zone
                END::text, pl.wf_loading_id, pl.stts_nm, pl.log, pl.wf_id, n.ctl_max, sh.plan_, sh.plan_next, sh.plan_dt, sh.plan_dt_next, sh.plan_prev, pl.max_dttm, pl.max_eff_from_dttm, pl.max_eff_to_dttm, age(sh.plan_ + '00:00:01'::interval,
                CASE
                    WHEN sh.plan_prev::date = '1900-01-01'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_prev
                END), age(
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_next
                END, sh.plan_ - '00:00:01'::interval), age(sh.plan_::timestamp with time zone, pl.max_eff_from_dttm::timestamp with time zone), age(n.ctl_max::date::timestamp with time zone, pl.max_eff_to_dttm::date::timestamp with time zone),
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END, nod.is_active
        ), link1 AS (
         SELECT l.node_id,
            l.schema_src_id,
            l.node_src_id,
            l.node_type_cd,
            l.src_cd,
            l.depth,
            l.tbl_type,
            l.max_dttm,
            l.max_eff_from_dttm,
            l.max_eff_to_dttm,
            l.scheduler_id,
            l.scheduler_type_src_id,
            l.node_type_src_id,
            l.period_type_id,
            l.every_times,
            l.period_type_comment,
            l.period_refresh_comment,
            l.plan_,
            l.plan_next,
            l.plan_dt,
            l.now_,
            l.plan_trg,
            l.plan_next_trg,
            l.plan_prev_trg,
            l.plan_fact_diff,
            l.fl_max_fact_execute,
            l.fl_hour_fail,
            l.is_wf_time_sched_active,
            l.dd_diff,
            l.err_stts_stg,
            l.err_stts_ods,
            l.alive_ods,
            l.status_log,
            l.diff_day,
            l.znk,
            l.status,
            l.date_plan_next,
            l.time_before_start,
            l.wf_loading_id,
            l.stts_nm,
            l.log,
            l.wf_id,
            l.plan_trg + '01:00:00'::interval AS hb1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '1 day'::interval
                    ELSE l.plan_trg + '01:00:00'::interval
                END AS b1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '2 days'::interval
                    ELSE l.plan_trg + '02:00:00'::interval
                END AS b2,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '3 days'::interval
                    ELSE l.plan_trg + '03:00:00'::interval
                END AS b3,
                CASE
                    WHEN (l.period_refresh_comment ~~ 'Останов%'::text OR l.is_active IS FALSE) AND l.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END AS is_active
           FROM link l
        ), win_1 AS (
         SELECT w.node_id,
            w.schema_src_id,
            w.node_src_id,
            w.depth,
            w.node_type_cd,
            w.scheduler_type_src_id,
            w.node_type_src_id,
            w.period_type_id,
            w.every_times,
            w.period_type_comment,
            w.period_refresh_comment,
            w.now_,
            w.plan_trg,
            w.plan_next_trg,
            w.plan_prev_trg,
            w.max_eff_from_dttm,
            w.max_eff_to_dttm,
            w.now_::timestamp with time zone - w.plan_trg::timestamp with time zone AS now_plan_diff,
            w.plan_fact_diff,
                CASE
                    WHEN w.now_ >= w.plan_trg AND w.now_ < w.plan_next_trg THEN 1
                    WHEN w.now_ >= w.plan_prev_trg AND w.now_ < w.plan_trg THEN 1
                    ELSE 0
                END AS current_fl,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_from_dttm::date >= w.plan_trg::date AND w.max_eff_from_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_from_dttm::date = w.plan_trg::date AND w.max_eff_from_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_from_dttm >= w.b1 AND w.max_eff_from_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b2 AND w.max_eff_from_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b3 AND w.max_eff_from_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_from_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END AS ready_str,
                CASE
                    WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                    WHEN w.max_eff_from_dttm < w.plan_trg THEN 0
                    WHEN w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm <= w.now_ THEN 1
                    WHEN w.max_eff_from_dttm >= w.now_ AND w.max_eff_from_dttm < w.plan_next_trg THEN 0
                    WHEN w.max_eff_from_dttm > w.plan_next_trg THEN 0
                    ELSE 0
                END AS ready_fl,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END AS ready_finished_str,
                CASE
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        ELSE 0
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 0
                    ELSE 0
                END AS ready_finished_fl,
            w.fl_max_fact_execute,
            w.fl_hour_fail,
                CASE
                    WHEN w.node_type_cd::text = 'Function'::text THEN w.node_id
                    ELSE NULL::text
                END AS func_node_id,
            n.src_node_id AS ctl_entity_node_id,
            n1.src_node_id AS ctl_wf_node_id,
            w.scheduler_id,
            w.src_cd,
            w.is_wf_time_sched_active,
            w.err_stts_stg,
            w.err_stts_ods,
            w.alive_ods,
            w.status_log,
            w.diff_day,
            w.znk,
            w.status,
            w.date_plan_next,
            w.time_before_start,
            sm.severity_max,
            m.severity,
            w.stts_nm,
            w.log,
            w.wf_id,
            w.wf_loading_id
           FROM link1 w
             LEFT JOIN dg_full.meta_edge_link n ON w.node_src_id = n.target_node_src_id::text AND w.schema_src_id = n.target_schema_src_id::text AND n.src_cd::text = 'CTL'::text AND n.src_node_type_cd = 'Flow'::text
             LEFT JOIN dg_full.meta_edge_link n1 ON n.src_node_src_id::text = n1.target_node_src_id::text AND n.src_schema_src_id::text = n1.target_schema_src_id::text AND n.src_cd::text = 'CTL'::text AND n1.src_node_type_cd = 'Entity'::text
             LEFT JOIN temp_sever_max sm ON sm.schema_src_id::text = w.schema_src_id AND sm.table_src_id::text = w.node_src_id
             LEFT JOIN temp_sever m ON m.schema_src_id::text = w.schema_src_id AND m.table_src_id::text = w.node_src_id AND m.start_dt = w.max_eff_from_dttm::date AND m.wf_load_id = w.wf_loading_id
          GROUP BY w.node_id, w.schema_src_id, w.node_src_id, w.depth, w.node_type_cd, w.scheduler_type_src_id, w.node_type_src_id, w.period_type_id, w.every_times, w.period_type_comment, w.period_refresh_comment, w.now_, w.plan_trg, w.plan_next_trg, w.plan_prev_trg, w.max_eff_from_dttm, w.max_eff_to_dttm, w.now_::timestamp with time zone - w.plan_trg::timestamp with time zone, w.plan_fact_diff,
                CASE
                    WHEN w.now_ >= w.plan_trg AND w.now_ < w.plan_next_trg THEN 1
                    WHEN w.now_ >= w.plan_prev_trg AND w.now_ < w.plan_trg THEN 1
                    ELSE 0
                END,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_from_dttm::date >= w.plan_trg::date AND w.max_eff_from_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_from_dttm::date = w.plan_trg::date AND w.max_eff_from_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_from_dttm >= w.b1 AND w.max_eff_from_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b2 AND w.max_eff_from_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b3 AND w.max_eff_from_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_from_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                    WHEN w.max_eff_from_dttm < w.plan_trg THEN 0
                    WHEN w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm <= w.now_ THEN 1
                    WHEN w.max_eff_from_dttm >= w.now_ AND w.max_eff_from_dttm < w.plan_next_trg THEN 0
                    WHEN w.max_eff_from_dttm > w.plan_next_trg THEN 0
                    ELSE 0
                END,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        ELSE 0
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 0
                    ELSE 0
                END, w.fl_max_fact_execute, w.fl_hour_fail,
                CASE
                    WHEN w.node_type_cd::text = 'Function'::text THEN w.node_id
                    ELSE NULL::text
                END, n.src_node_id, n1.src_node_id, w.scheduler_id, w.src_cd, w.is_wf_time_sched_active, w.err_stts_stg, w.err_stts_ods, w.alive_ods, w.status_log, w.diff_day, w.znk, w.status, w.date_plan_next, w.time_before_start, sm.severity_max, m.severity, w.stts_nm, w.log, w.wf_id, w.wf_loading_id
        )
 SELECT "Window".schema_src_id,
    "Window".node_src_id,
    "Window".scheduler_type_src_id,
    "Window".node_type_src_id,
    "Window".period_type_id,
    "Window".period_type_comment,
    "Window".period_refresh_comment,
    "Window".now_,
    "Window".plan_trg,
    "Window".plan_next_trg,
    "Window".now_plan_diff,
    "Window".fact_started,
    "Window".fact_ended,
    NULL::interval AS fact_plan_diff,
    "Window".ready_str,
    "Window".ready_fl,
    NULL::bigint AS v_cnt,
    NULL::bigint AS v_cnt_ready,
    NULL::text AS tbl_type,
    "Window".node_type_cd,
    NULL::integer AS is_active_objects,
    NULL::integer AS depth,
    NULL::text AS root_schema_src_id,
    NULL::text AS root_node_src_id,
    NULL::timestamp without time zone AS root_max_dttm,
    NULL::text AS root_tbl_type,
    NULL::text AS application_qs,
    "Window".plan_prev_trg,
    "Window".func_node_id,
    "Window".ctl_entity_node_id,
    "Window".ctl_wf_node_id,
    "Window".plan_fact_diff,
    (row_number() OVER (PARTITION BY "Window".schema_src_id, "Window".node_src_id, "Window".node_type_src_id, "Window".plan_trg::date ORDER BY COALESCE("Window".fact_ended, "Window".fact_started, '2999-12-31'::date::timestamp without time zone) DESC))::integer AS fl_max_fact_execute,
    "Window".fl_hour_fail,
    NULL::text AS root_node_id_array,
    NULL::text AS depth_array,
    "Window".scheduler_id,
    "Window".current_fl,
    "Window".src_cd,
    "Window".max_fact_dttm,
    "Window".every_times,
    "Window".is_wf_time_sched_active,
    "Window".err_stts_stg,
    "Window".err_stts_ods,
    "Window".severity_max,
    NULL::bigint AS root_severity_max,
    "Window".severity,
    NULL::double precision AS root_severity,
    "Window".alive_ods,
    "Window".status_log,
    "Window".diff_day,
    "Window".znk,
    "Window".status,
    "Window".date_plan_next,
    "Window".time_before_start,
    "Window".ready_finished_str,
    "Window".ready_finished_fl,
    "Window".severity_prc,
    "Window".stts_nm,
    "Window".log,
    "Window".wf_id,
    "Window".wf_loading_id
   FROM ( SELECT w2.schema_src_id,
            w2.node_src_id,
            w2.scheduler_type_src_id,
            w2.node_type_src_id,
            w2.period_type_id,
            w2.period_type_comment,
            w2.period_refresh_comment,
            w2.now_::timestamp with time zone AS now_,
            w2.plan_trg,
            w2.plan_next_trg,
            w2.now_plan_diff,
            w2.max_eff_from_dttm AS fact_started,
            w2.max_eff_to_dttm AS fact_ended,
            w2.ready_str,
            w2.ready_fl,
            w2.node_type_cd,
            w2.plan_prev_trg,
            w2.func_node_id,
            w2.ctl_entity_node_id,
            w2.ctl_wf_node_id,
            w2.plan_fact_diff,
            w2.fl_max_fact_execute,
            w2.fl_hour_fail,
            w2.scheduler_id,
            w2.current_fl,
            w2.src_cd,
            m.max_fact_dttm,
            w2.every_times,
            w2.is_wf_time_sched_active,
            w2.err_stts_stg,
            w2.err_stts_ods,
            w2.severity_max,
            w2.severity,
            w2.alive_ods,
            w2.status_log,
            w2.diff_day,
            w2.znk,
            w2.status,
            w2.date_plan_next,
            w2.time_before_start,
            w2.ready_finished_str,
            w2.ready_finished_fl,
            round((w2.severity / w2.severity_max::double precision * 100::double precision)::numeric, 2) AS severity_prc,
            w2.stts_nm,
            w2.log,
            w2.wf_id,
            w2.wf_loading_id
           FROM win_1 w2
             LEFT JOIN max_fact m ON w2.schema_src_id = m.sch_name AND w2.node_src_id = m.tbl_name
          WHERE 1 = 1
          GROUP BY w2.schema_src_id, w2.node_src_id, w2.scheduler_type_src_id, w2.node_type_src_id, w2.period_type_id, w2.period_type_comment, w2.period_refresh_comment, w2.now_, w2.plan_trg, w2.plan_next_trg, w2.now_plan_diff, w2.max_eff_from_dttm, w2.max_eff_to_dttm, w2.ready_str, w2.ready_fl, w2.node_type_cd, w2.plan_prev_trg, w2.func_node_id, w2.ctl_entity_node_id, w2.ctl_wf_node_id, w2.plan_fact_diff, w2.fl_max_fact_execute, w2.fl_hour_fail, w2.scheduler_id, w2.current_fl, w2.src_cd, m.max_fact_dttm, w2.every_times, w2.is_wf_time_sched_active, w2.err_stts_stg, w2.err_stts_ods, w2.severity_max, w2.severity, w2.alive_ods, w2.status_log, w2.diff_day, w2.znk, w2.status, w2.date_plan_next, w2.time_before_start, w2.ready_finished_str, w2.ready_finished_fl, w2.stts_nm, w2.log, w2.wf_id, w2.wf_loading_id) "Window"(schema_src_id, node_src_id, scheduler_type_src_id, node_type_src_id, period_type_id, period_type_comment, period_refresh_comment, now_, plan_trg, plan_next_trg, now_plan_diff, fact_started, fact_ended, ready_str, ready_fl, node_type_cd, plan_prev_trg, func_node_id, ctl_entity_node_id, ctl_wf_node_id, plan_fact_diff, fl_max_fact_execute, fl_hour_fail, scheduler_id, current_fl, src_cd, max_fact_dttm, every_times, is_wf_time_sched_active, err_stts_stg, err_stts_ods, severity_max, severity, alive_ods, status_log, diff_day, znk, status, date_plan_next, time_before_start, ready_finished_str, ready_finished_fl, severity_prc, stts_nm, log, wf_id, wf_loading_id);


-- dg_full.vmeta_scheduler_plan_fact_lg source

CREATE OR REPLACE VIEW dg_full.vmeta_scheduler_plan_fact_lg
AS WITH temp_now AS (
         SELECT max(d.processing_end_dttm) AS ctl_max
           FROM s_grnplm_as_cib_gm_meta_core.dsc_ctl_processing d
        ), temp_sever AS (
         SELECT f.load_dttm::date AS start_dt,
            f.schema_src_id,
            f.table_src_id,
            f.wf_load_id,
            sum(COALESCE(f.final_severity_score, 0::double precision)) AS severity
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
             CROSS JOIN temp_now n
          WHERE 1 = 1 AND f.load_dttm::date > date_trunc('month'::text, n.ctl_max)
          GROUP BY f.load_dttm::date, f.schema_src_id, f.table_src_id, f.wf_load_id
        ), temp_sever_max AS (
         SELECT tt.schema_src_id,
            tt.table_src_id,
            sum(COALESCE(tt.severity, 0)) AS severity_max
           FROM ( SELECT o.schema_src_id,
                    o.table_src_id,
                    l.screen_template_id,
                    max(p.priority_src_id) AS severity,
                    max(p.priority_src_id)::real / count(*)::real AS severity_cn
                   FROM dg_full.vmeta_screen_link l
                     JOIN dg_full.meta_screen_template_ref_table st ON l.screen_template_id = st.screen_template_id
                     JOIN dg_full.vmeta_object_ref_table o ON l.object_group_id = o.object_group_id AND o.attribute_src_id IS NULL
                     JOIN dg_full.meta_priority_ref_table p ON st.priority_cd = p.priority_cd
                  WHERE 1 = 1
                  GROUP BY o.schema_src_id, o.table_src_id, l.screen_template_id) tt
          GROUP BY tt.schema_src_id, tt.table_src_id
        ), max_fact AS (
         SELECT f.sch_name,
            f.tbl_name,
            max(f.max_eff_to_dttm) AS max_fact_dttm
           FROM dg_full.vmeta_execute_fact f
          GROUP BY f.sch_name, f.tbl_name
        ), link AS (
         SELECT (sh.schema_src_id || '||'::text) || sh.node_src_id AS node_id,
            sh.schema_src_id,
            sh.node_src_id,
            nt.node_type_cd,
            sh.src_cd,
            1::bigint AS depth,
            pl.tbl_type,
            sh.scheduler_id,
            sh.scheduler_type_src_id,
            sh.node_type_src_id,
            sh.period_type_id,
            sh.every_times,
            sh.period_type_comment,
            sh.period_refresh_comment,
            COALESCE(pl.fl_max_fact_execute, 0) AS fl_max_fact_execute,
            0 AS fl_hour_fail,
            sh.is_wf_time_sched_active,
            pl.err_stts_stg,
            pl.err_stts_ods,
            pl.alive_ods,
            pl.status_log,
                CASE
                    WHEN (n.ctl_max::date - pl.max_eff_to_dttm::date) <> 1 THEN ''::text
                    WHEN n.ctl_max::time without time zone <= pl.avg_start_time::time without time zone THEN ''::text
                    ELSE '-'::text
                END AS znk,
                CASE
                    WHEN (pl.today_start + pl.avg_ods_duration + '00:15:00'::interval) < n.ctl_max::time without time zone::interval AND pl.max_eff_to_dttm IS NULL THEN 'Long Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) < '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL THEN 'Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) >= '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL AND n.ctl_max::time without time zone::interval < (pl.avg_start_time + pl.avg_ods_duration + '00:40:00'::interval) THEN 'Attention: Run > 20 min'::text
                    WHEN pl.max_eff_to_dttm::date = n.ctl_max::date THEN 'Ok'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) > n.ctl_max::date THEN 'Ok'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:30:00'::interval) THEN 'ERROR'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:15:00'::interval) THEN 'Attention'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND sh.plan_dt_next = n.ctl_max::date AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN 'TODAY'::text
                    WHEN sh.plan_dt_next IS NULL THEN 'TODAY'::text
                    WHEN pl.max_eff_to_dttm::date < n.ctl_max::date THEN '-'::text
                    ELSE '-'::text
                END AS status,
                CASE
                    WHEN n.ctl_max::date = COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN
                    CASE
                        WHEN n.ctl_max::time without time zone::interval <= pl.avg_start_time THEN (pl.avg_start_time - n.ctl_max::time without time zone::interval)::time without time zone
                        ELSE n.ctl_max::time without time zone - pl.avg_start_time
                    END
                    ELSE '00:00:00'::time without time zone
                END::text AS time_before_start,
            pl.wf_loading_id,
            pl.stts_nm,
            pl.log,
            pl.wf_id,
            n.ctl_max AS now_,
            sh.plan_,
            sh.plan_next,
            sh.plan_dt,
            sh.plan_dt_next AS date_plan_next,
            sh.plan_prev AS plan_prev_trg,
            sh.plan_ AS plan_trg,
            sh.plan_next AS plan_next_trg,
            pl.max_dttm,
            pl.max_eff_from_dttm,
            pl.max_eff_to_dttm,
            age(sh.plan_ + '00:00:01'::interval,
                CASE
                    WHEN sh.plan_prev::date = '1900-01-01'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_prev
                END) AS plan_prev_plan_,
            age(
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_next
                END, sh.plan_ - '00:00:01'::interval) AS plan_plan_next,
            age(sh.plan_::timestamp with time zone, pl.max_eff_from_dttm::timestamp with time zone) AS plan_fact_diff,
            age(n.ctl_max::date::timestamp with time zone, pl.max_eff_to_dttm::date::timestamp with time zone) AS diff_day,
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END AS dd_diff,
            nod.is_active
           FROM dg_full.meta_scheduler_plan sh
             CROSS JOIN temp_now n
             JOIN dg_full.meta_node_type_ref_table nt ON sh.node_type_src_id = nt.node_type_src_id
             LEFT JOIN dg_full.vmeta_execute_fact pl ON sh.node_src_id = pl.tbl_name AND sh.schema_src_id = pl.sch_name AND sh.node_type_src_id = pl.node_type_src_id AND pl.max_eff_from_dttm::date >= sh.plan_::date AND pl.max_eff_from_dttm::date < sh.plan_next::date AND (pl.stts_nm <> ALL (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]))
             LEFT JOIN dg_full.meta_node_ref_table nod ON sh.schema_src_id = nod.schema_src_id::text AND sh.node_src_id = nod.node_src_id::text AND sh.node_type_src_id = nod.node_type_src_id
          WHERE 1 = 1 AND sh.schema_src_id !~~ '%_stg_%'::text
          GROUP BY (sh.schema_src_id || '||'::text) || sh.node_src_id, sh.schema_src_id, sh.node_src_id, nt.node_type_cd, sh.src_cd, 1::bigint, pl.tbl_type, sh.scheduler_id, sh.scheduler_type_src_id, sh.node_type_src_id, sh.period_type_id, sh.every_times, sh.period_type_comment, sh.period_refresh_comment, COALESCE(pl.fl_max_fact_execute, 0), 0::integer, sh.is_wf_time_sched_active, pl.err_stts_stg, pl.err_stts_ods, pl.alive_ods, pl.status_log,
                CASE
                    WHEN (n.ctl_max::date - pl.max_eff_to_dttm::date) <> 1 THEN ''::text
                    WHEN n.ctl_max::time without time zone <= pl.avg_start_time::time without time zone THEN ''::text
                    ELSE '-'::text
                END,
                CASE
                    WHEN (pl.today_start + pl.avg_ods_duration + '00:15:00'::interval) < n.ctl_max::time without time zone::interval AND pl.max_eff_to_dttm IS NULL THEN 'Long Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) < '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL THEN 'Run'::text
                    WHEN GREATEST(pl.avg_start_time - pl.today_start, pl.today_start - pl.avg_start_time) >= '00:20:00'::interval AND pl.max_eff_to_dttm IS NULL AND n.ctl_max::time without time zone::interval < (pl.avg_start_time + pl.avg_ods_duration + '00:40:00'::interval) THEN 'Attention: Run > 20 min'::text
                    WHEN pl.max_eff_to_dttm::date = n.ctl_max::date THEN 'Ok'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) > n.ctl_max::date THEN 'Ok'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:30:00'::interval) THEN 'ERROR'::text
                    WHEN sh.plan_::time without time zone::interval > (pl.avg_start_time + pl.avg_ods_duration + '00:15:00'::interval) THEN 'Attention'::text
                    WHEN pl.max_eff_to_dttm >= sh.plan_dt AND pl.max_eff_to_dttm <= sh.plan_dt_next AND sh.plan_dt_next = n.ctl_max::date AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN 'TODAY'::text
                    WHEN sh.plan_dt_next IS NULL THEN 'TODAY'::text
                    WHEN pl.max_eff_to_dttm::date < n.ctl_max::date THEN '-'::text
                    ELSE '-'::text
                END,
                CASE
                    WHEN n.ctl_max::date = COALESCE(sh.plan_dt_next, n.ctl_max::date::timestamp without time zone) AND pl.max_eff_to_dttm::date <> n.ctl_max::date THEN
                    CASE
                        WHEN n.ctl_max::time without time zone::interval <= pl.avg_start_time THEN (pl.avg_start_time - n.ctl_max::time without time zone::interval)::time without time zone
                        ELSE n.ctl_max::time without time zone - pl.avg_start_time
                    END
                    ELSE '00:00:00'::time without time zone
                END::text, pl.wf_loading_id, pl.stts_nm, pl.log, pl.wf_id, n.ctl_max, sh.plan_, sh.plan_next, sh.plan_dt, sh.plan_dt_next, sh.plan_prev, pl.max_dttm, pl.max_eff_from_dttm, pl.max_eff_to_dttm, age(sh.plan_ + '00:00:01'::interval,
                CASE
                    WHEN sh.plan_prev::date = '1900-01-01'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_prev
                END), age(
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN n.ctl_max::date::timestamp without time zone
                    ELSE sh.plan_next
                END, sh.plan_ - '00:00:01'::interval), age(sh.plan_::timestamp with time zone, pl.max_eff_from_dttm::timestamp with time zone), age(n.ctl_max::date::timestamp with time zone, pl.max_eff_to_dttm::date::timestamp with time zone),
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END, nod.is_active
        ), link1 AS (
         SELECT l.node_id,
            l.schema_src_id,
            l.node_src_id,
            l.node_type_cd,
            l.src_cd,
            l.depth,
            l.tbl_type,
            l.max_dttm,
            l.max_eff_from_dttm,
            l.max_eff_to_dttm,
            l.scheduler_id,
            l.scheduler_type_src_id,
            l.node_type_src_id,
            l.period_type_id,
            l.every_times,
            l.period_type_comment,
            l.period_refresh_comment,
            l.plan_,
            l.plan_next,
            l.plan_dt,
            l.now_,
            l.plan_trg,
            l.plan_next_trg,
            l.plan_prev_trg,
            l.plan_fact_diff,
            l.fl_max_fact_execute,
            l.fl_hour_fail,
            l.is_wf_time_sched_active,
            l.dd_diff,
            l.err_stts_stg,
            l.err_stts_ods,
            l.alive_ods,
            l.status_log,
            l.diff_day,
            l.znk,
            l.status,
            l.date_plan_next,
            l.time_before_start,
            l.wf_loading_id,
            l.stts_nm,
            l.log,
            l.wf_id,
            l.plan_trg + '01:00:00'::interval AS hb1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '1 day'::interval
                    ELSE l.plan_trg + '01:00:00'::interval
                END AS b1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '2 days'::interval
                    ELSE l.plan_trg + '02:00:00'::interval
                END AS b2,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '3 days'::interval
                    ELSE l.plan_trg + '03:00:00'::interval
                END AS b3,
                CASE
                    WHEN (l.period_refresh_comment ~~ 'Останов%'::text OR l.is_active IS FALSE) AND l.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END AS is_active
           FROM link l
        ), win_1 AS (
         SELECT w.node_id,
            w.schema_src_id,
            w.node_src_id,
            w.depth,
            w.node_type_cd,
            w.scheduler_type_src_id,
            w.node_type_src_id,
            w.period_type_id,
            w.every_times,
            w.period_type_comment,
            w.period_refresh_comment,
            w.now_,
            w.plan_trg,
            w.plan_next_trg,
            w.plan_prev_trg,
            w.max_eff_from_dttm,
            w.max_eff_to_dttm,
            w.now_::timestamp with time zone - w.plan_trg::timestamp with time zone AS now_plan_diff,
            w.plan_fact_diff,
                CASE
                    WHEN w.now_ >= w.plan_trg AND w.now_ < w.plan_next_trg THEN 1
                    WHEN w.now_ >= w.plan_prev_trg AND w.now_ < w.plan_trg THEN 1
                    ELSE 0
                END AS current_fl,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_from_dttm::date >= w.plan_trg::date AND w.max_eff_from_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_from_dttm::date = w.plan_trg::date AND w.max_eff_from_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_from_dttm >= w.b1 AND w.max_eff_from_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b2 AND w.max_eff_from_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b3 AND w.max_eff_from_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_from_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END AS ready_str,
                CASE
                    WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                    WHEN w.max_eff_from_dttm < w.plan_trg THEN 0
                    WHEN w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm <= w.now_ THEN 1
                    WHEN w.max_eff_from_dttm >= w.now_ AND w.max_eff_from_dttm < w.plan_next_trg THEN 0
                    WHEN w.max_eff_from_dttm > w.plan_next_trg THEN 0
                    ELSE 0
                END AS ready_fl,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END AS ready_finished_str,
                CASE
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        ELSE 0
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 0
                    ELSE 0
                END AS ready_finished_fl,
            w.fl_max_fact_execute,
            w.fl_hour_fail,
                CASE
                    WHEN w.node_type_cd::text = 'Function'::text THEN w.node_id
                    ELSE NULL::text
                END AS func_node_id,
            n.src_node_id AS ctl_entity_node_id,
            n1.src_node_id AS ctl_wf_node_id,
            w.scheduler_id,
            w.src_cd,
            w.is_wf_time_sched_active,
            w.err_stts_stg,
            w.err_stts_ods,
            w.alive_ods,
            w.status_log,
            w.diff_day,
            w.znk,
            w.status,
            w.date_plan_next,
            w.time_before_start,
            sm.severity_max,
            m.severity,
            w.stts_nm,
            w.log,
            w.wf_id,
            w.wf_loading_id
           FROM link1 w
             LEFT JOIN dg_full.meta_edge_link n ON w.node_src_id = n.target_node_src_id::text AND w.schema_src_id = n.target_schema_src_id::text AND n.src_cd::text = 'CTL'::text AND n.src_node_type_cd = 'Flow'::text
             LEFT JOIN dg_full.meta_edge_link n1 ON n.src_node_src_id::text = n1.target_node_src_id::text AND n.src_schema_src_id::text = n1.target_schema_src_id::text AND n.src_cd::text = 'CTL'::text AND n1.src_node_type_cd = 'Entity'::text
             LEFT JOIN temp_sever_max sm ON sm.schema_src_id::text = w.schema_src_id AND sm.table_src_id::text = w.node_src_id
             LEFT JOIN temp_sever m ON m.schema_src_id::text = w.schema_src_id AND m.table_src_id::text = w.node_src_id AND m.start_dt = w.max_eff_from_dttm::date AND m.wf_load_id = w.wf_loading_id
          GROUP BY w.node_id, w.schema_src_id, w.node_src_id, w.depth, w.node_type_cd, w.scheduler_type_src_id, w.node_type_src_id, w.period_type_id, w.every_times, w.period_type_comment, w.period_refresh_comment, w.now_, w.plan_trg, w.plan_next_trg, w.plan_prev_trg, w.max_eff_from_dttm, w.max_eff_to_dttm, w.now_::timestamp with time zone - w.plan_trg::timestamp with time zone, w.plan_fact_diff,
                CASE
                    WHEN w.now_ >= w.plan_trg AND w.now_ < w.plan_next_trg THEN 1
                    WHEN w.now_ >= w.plan_prev_trg AND w.now_ < w.plan_trg THEN 1
                    ELSE 0
                END,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_from_dttm::date >= w.plan_trg::date AND w.max_eff_from_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_from_dttm::date = w.plan_trg::date AND w.max_eff_from_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_from_dttm >= w.b1 AND w.max_eff_from_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b2 AND w.max_eff_from_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_from_dttm >= w.b3 AND w.max_eff_from_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_from_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                    WHEN w.max_eff_from_dttm < w.plan_trg THEN 0
                    WHEN w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm <= w.now_ THEN 1
                    WHEN w.max_eff_from_dttm >= w.now_ AND w.max_eff_from_dttm < w.plan_next_trg THEN 0
                    WHEN w.max_eff_from_dttm > w.plan_next_trg THEN 0
                    ELSE 0
                END,
                CASE
                    WHEN w.is_active IS FALSE THEN 'gray'::text
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                        WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 'green'::text
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 'yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 'd yellow'::text
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 'dd yellow'::text
                        ELSE 'red'::text
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN w.max_eff_to_dttm::date >= w.plan_trg::date AND w.max_eff_to_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
                    CASE
                        WHEN w.max_eff_to_dttm::date = w.plan_trg::date AND w.max_eff_to_dttm::time without time zone < w.plan_trg::time without time zone THEN 1
                        WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_to_dttm >= w.plan_trg AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        WHEN w.max_eff_to_dttm >= w.b1 AND w.max_eff_to_dttm <= w.b2 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b2 AND w.max_eff_to_dttm <= w.b3 THEN 1
                        WHEN w.max_eff_to_dttm >= w.b3 AND w.max_eff_to_dttm < w.plan_next_trg THEN 1
                        ELSE 0
                    END
                    WHEN w.max_eff_to_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 0
                    ELSE 0
                END, w.fl_max_fact_execute, w.fl_hour_fail,
                CASE
                    WHEN w.node_type_cd::text = 'Function'::text THEN w.node_id
                    ELSE NULL::text
                END, n.src_node_id, n1.src_node_id, w.scheduler_id, w.src_cd, w.is_wf_time_sched_active, w.err_stts_stg, w.err_stts_ods, w.alive_ods, w.status_log, w.diff_day, w.znk, w.status, w.date_plan_next, w.time_before_start, sm.severity_max, m.severity, w.stts_nm, w.log, w.wf_id, w.wf_loading_id
        )
 SELECT "Window".schema_src_id,
    "Window".node_src_id,
    "Window".scheduler_type_src_id,
    "Window".node_type_src_id,
    "Window".period_type_id,
    "Window".period_type_comment,
    "Window".period_refresh_comment,
    "Window".now_,
    "Window".plan_trg,
    "Window".plan_next_trg,
    "Window".now_plan_diff,
    "Window".fact_started,
    "Window".fact_ended,
    NULL::interval AS fact_plan_diff,
    "Window".ready_str,
    "Window".ready_fl,
    NULL::bigint AS v_cnt,
    NULL::bigint AS v_cnt_ready,
    NULL::text AS tbl_type,
    "Window".node_type_cd,
    NULL::integer AS is_active_objects,
    NULL::integer AS depth,
    NULL::text AS root_schema_src_id,
    NULL::text AS root_node_src_id,
    NULL::timestamp without time zone AS root_max_dttm,
    NULL::text AS root_tbl_type,
    NULL::text AS application_qs,
    "Window".plan_prev_trg,
    "Window".func_node_id,
    "Window".ctl_entity_node_id,
    "Window".ctl_wf_node_id,
    "Window".plan_fact_diff,
    (row_number() OVER (PARTITION BY "Window".schema_src_id, "Window".node_src_id, "Window".node_type_src_id, "Window".plan_trg::date ORDER BY COALESCE("Window".fact_ended, "Window".fact_started, '2999-12-31'::date::timestamp without time zone) DESC))::integer AS fl_max_fact_execute,
    "Window".fl_hour_fail,
    NULL::text AS root_node_id_array,
    NULL::text AS depth_array,
    "Window".scheduler_id,
    "Window".current_fl,
    "Window".src_cd,
    "Window".max_fact_dttm,
    "Window".every_times,
    "Window".is_wf_time_sched_active,
    "Window".err_stts_stg,
    "Window".err_stts_ods,
    "Window".severity_max,
    NULL::bigint AS root_severity_max,
    "Window".severity,
    NULL::double precision AS root_severity,
    "Window".alive_ods,
    "Window".status_log,
    "Window".diff_day,
    "Window".znk,
    "Window".status,
    "Window".date_plan_next,
    "Window".time_before_start,
    "Window".ready_finished_str,
    "Window".ready_finished_fl,
    "Window".severity_prc,
    "Window".stts_nm,
    "Window".log,
    "Window".wf_id,
    "Window".wf_loading_id
   FROM ( SELECT w2.schema_src_id,
            w2.node_src_id,
            w2.scheduler_type_src_id,
            w2.node_type_src_id,
            w2.period_type_id,
            w2.period_type_comment,
            w2.period_refresh_comment,
            w2.now_::timestamp with time zone AS now_,
            w2.plan_trg,
            w2.plan_next_trg,
            w2.now_plan_diff,
            w2.max_eff_from_dttm AS fact_started,
            w2.max_eff_to_dttm AS fact_ended,
            w2.ready_str,
            w2.ready_fl,
            w2.node_type_cd,
            w2.plan_prev_trg,
            w2.func_node_id,
            w2.ctl_entity_node_id,
            w2.ctl_wf_node_id,
            w2.plan_fact_diff,
            w2.fl_max_fact_execute,
            w2.fl_hour_fail,
            w2.scheduler_id,
            w2.current_fl,
            w2.src_cd,
            m.max_fact_dttm,
            w2.every_times,
            w2.is_wf_time_sched_active,
            w2.err_stts_stg,
            w2.err_stts_ods,
            w2.severity_max,
            w2.severity,
            w2.alive_ods,
            w2.status_log,
            w2.diff_day,
            w2.znk,
            w2.status,
            w2.date_plan_next,
            w2.time_before_start,
            w2.ready_finished_str,
            w2.ready_finished_fl,
            round((w2.severity / w2.severity_max::double precision * 100::double precision)::numeric, 2) AS severity_prc,
            w2.stts_nm,
            w2.log,
            w2.wf_id,
            w2.wf_loading_id
           FROM win_1 w2
             LEFT JOIN max_fact m ON w2.schema_src_id = m.sch_name AND w2.node_src_id = m.tbl_name
          WHERE 1 = 1
          GROUP BY w2.schema_src_id, w2.node_src_id, w2.scheduler_type_src_id, w2.node_type_src_id, w2.period_type_id, w2.period_type_comment, w2.period_refresh_comment, w2.now_, w2.plan_trg, w2.plan_next_trg, w2.now_plan_diff, w2.max_eff_from_dttm, w2.max_eff_to_dttm, w2.ready_str, w2.ready_fl, w2.node_type_cd, w2.plan_prev_trg, w2.func_node_id, w2.ctl_entity_node_id, w2.ctl_wf_node_id, w2.plan_fact_diff, w2.fl_max_fact_execute, w2.fl_hour_fail, w2.scheduler_id, w2.current_fl, w2.src_cd, m.max_fact_dttm, w2.every_times, w2.is_wf_time_sched_active, w2.err_stts_stg, w2.err_stts_ods, w2.severity_max, w2.severity, w2.alive_ods, w2.status_log, w2.diff_day, w2.znk, w2.status, w2.date_plan_next, w2.time_before_start, w2.ready_finished_str, w2.ready_finished_fl, w2.stts_nm, w2.log, w2.wf_id, w2.wf_loading_id) "Window"(schema_src_id, node_src_id, scheduler_type_src_id, node_type_src_id, period_type_id, period_type_comment, period_refresh_comment, now_, plan_trg, plan_next_trg, now_plan_diff, fact_started, fact_ended, ready_str, ready_fl, node_type_cd, plan_prev_trg, func_node_id, ctl_entity_node_id, ctl_wf_node_id, plan_fact_diff, fl_max_fact_execute, fl_hour_fail, scheduler_id, current_fl, src_cd, max_fact_dttm, every_times, is_wf_time_sched_active, err_stts_stg, err_stts_ods, severity_max, severity, alive_ods, status_log, diff_day, znk, status, date_plan_next, time_before_start, ready_finished_str, ready_finished_fl, severity_prc, stts_nm, log, wf_id, wf_loading_id);


-- dg_full.vmeta_scheduler_plan_fact_sht source

CREATE OR REPLACE VIEW dg_full.vmeta_scheduler_plan_fact_sht
AS WITH temp_now AS (
         SELECT max(d.processing_end_dttm) AS ctl_max
           FROM s_grnplm_as_cib_gm_meta_core.dsc_ctl_processing d
        ), max_fact AS (
         SELECT f.sch_name,
            f.tbl_name,
            max(f.max_eff_to_dttm) AS max_fact_dttm
           FROM dg_full.vmeta_execute_fact f
          GROUP BY f.sch_name, f.tbl_name
        ), link AS (
         SELECT (sh.schema_src_id || '||'::text) || sh.node_src_id AS node_id,
            sh.schema_src_id,
            sh.node_src_id,
            nt.node_type_cd,
            sh.node_type_src_id,
            pl.err_stts_ods,
            pl.stts_nm,
            n.ctl_max AS now_,
            sh.plan_ AS plan_trg,
            sh.plan_prev AS plan_prev_trg,
            sh.plan_next AS plan_next_trg,
            pl.max_eff_from_dttm,
                CASE
                    WHEN (sh.period_refresh_comment ~~ 'Останов%'::text OR nod.is_active IS FALSE) AND sh.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END AS is_active,
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END AS dd_diff
           FROM dg_full.meta_scheduler_plan sh
             CROSS JOIN temp_now n
             JOIN dg_full.meta_node_type_ref_table nt ON sh.node_type_src_id = nt.node_type_src_id
             LEFT JOIN dg_full.vmeta_execute_fact pl ON sh.node_src_id = pl.tbl_name AND sh.schema_src_id = pl.sch_name AND sh.node_type_src_id = pl.node_type_src_id AND pl.max_eff_from_dttm::date >= sh.plan_::date AND pl.max_eff_from_dttm::date < sh.plan_next::date AND (pl.stts_nm <> ALL (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]))
             LEFT JOIN dg_full.meta_node_ref_table nod ON sh.schema_src_id = nod.schema_src_id::text AND sh.node_src_id = nod.node_src_id::text AND sh.node_type_src_id = nod.node_type_src_id
          WHERE 1 = 1 AND sh.schema_src_id !~~ '%_stg_%'::text AND
                CASE
                    WHEN n.ctl_max >= sh.plan_ AND n.ctl_max < sh.plan_next THEN 1
                    WHEN n.ctl_max >= sh.plan_prev AND n.ctl_max < sh.plan_ THEN 1
                    ELSE 0
                END = 1
          GROUP BY (sh.schema_src_id || '||'::text) || sh.node_src_id, sh.schema_src_id, sh.node_src_id, nt.node_type_cd, sh.node_type_src_id, pl.err_stts_ods, pl.stts_nm, n.ctl_max, sh.plan_, sh.plan_prev, sh.plan_next, pl.max_eff_from_dttm,
                CASE
                    WHEN (sh.period_refresh_comment ~~ 'Останов%'::text OR nod.is_active IS FALSE) AND sh.is_wf_time_sched_active IS FALSE THEN false
                    ELSE true
                END,
                CASE
                    WHEN sh.plan_next::date = '2999-12-30'::date THEN date_part('day'::text, sh.plan_ - sh.plan_prev)
                    ELSE date_part('day'::text, sh.plan_next + '00:00:01'::interval - sh.plan_)
                END
        ), link1 AS (
         SELECT l.node_id,
            l.schema_src_id,
            l.node_src_id,
            l.node_type_cd,
            l.now_,
            l.plan_trg,
            l.plan_next_trg,
            l.plan_prev_trg,
            l.is_active,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '1 day'::interval
                    ELSE l.plan_trg + '01:00:00'::interval
                END AS b1,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '2 days'::interval
                    ELSE l.plan_trg + '02:00:00'::interval
                END AS b2,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '3 days'::interval
                    ELSE l.plan_trg + '03:00:00'::interval
                END AS b3,
            l.max_eff_from_dttm,
            l.err_stts_ods,
            l.stts_nm
           FROM link l
          GROUP BY l.node_id, l.schema_src_id, l.node_src_id, l.node_type_cd, l.now_, l.plan_trg, l.plan_next_trg, l.plan_prev_trg, l.is_active,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '1 day'::interval
                    ELSE l.plan_trg + '01:00:00'::interval
                END,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '2 days'::interval
                    ELSE l.plan_trg + '02:00:00'::interval
                END,
                CASE
                    WHEN l.dd_diff > 3::double precision THEN l.plan_trg + '3 days'::interval
                    ELSE l.plan_trg + '03:00:00'::interval
                END, l.max_eff_from_dttm, l.err_stts_ods, l.stts_nm
        )
 SELECT w.schema_src_id,
    w.node_src_id,
    w.node_type_cd,
        CASE
            WHEN w.is_active IS FALSE THEN 'gray'::text
            WHEN w.max_eff_from_dttm::date >= w.plan_trg::date AND w.max_eff_from_dttm::date < w.plan_next_trg::date AND w.now_::date >= w.plan_trg::date AND w.now_::date <= w.plan_next_trg::date THEN
            CASE
                WHEN w.max_eff_from_dttm::date = w.plan_trg::date AND w.max_eff_from_dttm::time without time zone < w.plan_trg::time without time zone THEN 'blue'::text
                WHEN w.err_stts_ods = ANY (ARRAY['EVENT-WAIT'::text, 'TIME-WAIT'::text]) THEN 'gray'::text
                WHEN w.stts_nm = 'SUCCESS'::text AND w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm < w.plan_next_trg THEN 'green'::text
                WHEN w.max_eff_from_dttm >= w.b1 AND w.max_eff_from_dttm <= w.b2 THEN 'yellow'::text
                WHEN w.max_eff_from_dttm >= w.b2 AND w.max_eff_from_dttm <= w.b3 THEN 'd yellow'::text
                WHEN w.max_eff_from_dttm >= w.b3 AND w.max_eff_from_dttm < w.plan_next_trg THEN 'dd yellow'::text
                ELSE 'red'::text
            END
            WHEN w.max_eff_from_dttm IS NULL AND w.now_::date >= w.plan_trg::date AND w.now_::date < w.plan_next_trg::date AND w.now_::time without time zone > w.plan_trg::time without time zone THEN 'red'::text
            ELSE NULL::text
        END AS ready_str,
        CASE
            WHEN w.max_eff_from_dttm < w.plan_trg THEN 0
            WHEN w.max_eff_from_dttm >= w.plan_trg AND w.max_eff_from_dttm <= w.now_ THEN 1
            WHEN w.max_eff_from_dttm >= w.now_ AND w.max_eff_from_dttm < w.plan_next_trg THEN 0
            WHEN w.max_eff_from_dttm > w.plan_next_trg THEN 0
            ELSE 0
        END AS ready_fl,
    w.plan_trg
   FROM link1 w;


-- dg_full.vmeta_scheduler_screen_link source

CREATE OR REPLACE VIEW dg_full.vmeta_scheduler_screen_link
AS WITH grp AS (
         SELECT o.object_group_id,
            o.object_alias,
            og.object_group_name,
            og.object_group_descr,
            o.object_id,
            o.schema_src_id,
            o.table_src_id,
            o.attribute_src_id
           FROM dg_full.vmeta_object_group_ref_table og
             JOIN dg_full.vmeta_object_ref_table o ON og.object_group_id = o.object_group_id
        ), stmpl AS (
         SELECT st.screen_template_id,
            st.screen_category,
            st.descr,
            st.screen_sql,
            sta.object_alias AS sta_object_alias,
            sta.attribute_src_id AS sta_attribute_src_id,
                CASE
                    WHEN st.screen_template_id = ANY (ARRAY[13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73]) THEN p_1.priority_src_id
                    ELSE NULL::integer
                END AS priority_src_id,
                CASE
                    WHEN st.screen_template_id = ANY (ARRAY[13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73]) THEN p_1.priority_cd
                    ELSE NULL::text
                END AS priority_cd,
                CASE
                    WHEN st.screen_template_id = ANY (ARRAY[13, 10014, 10001, 1, 10074, 87, 10078, 10073, 73]) THEN p_1.priority_nm
                    ELSE NULL::text
                END AS priority_nm
           FROM dg_full.meta_screen_template_ref_table st
             JOIN dg_full.meta_screen_template_alias_ref_table sta ON sta.screen_template_id = st.screen_template_id
             LEFT JOIN dg_full.meta_priority_ref_table p_1 ON st.priority_cd = p_1.priority_cd
        ), tmp_screen AS (
         SELECT l.screen_id,
            l.screen_template_id,
            l.object_group_id,
            stmpl.screen_category,
            stmpl.descr,
            stmpl.screen_sql,
            stmpl.sta_object_alias,
            stmpl.sta_attribute_src_id,
            grp.object_group_name,
            grp.object_group_descr,
            grp.object_id,
            grp.schema_src_id,
            grp.table_src_id,
            grp.attribute_src_id,
            grp.object_alias,
                CASE
                    WHEN grp.attribute_src_id IS NULL THEN stmpl.priority_src_id
                    ELSE NULL::integer
                END AS priority_src_id,
                CASE
                    WHEN grp.attribute_src_id IS NULL THEN stmpl.priority_cd
                    ELSE NULL::text
                END AS priority_cd,
                CASE
                    WHEN grp.attribute_src_id IS NULL THEN stmpl.priority_nm
                    ELSE NULL::text
                END AS priority_nm
           FROM dg_full.vmeta_screen_link l
             LEFT JOIN stmpl ON stmpl.screen_template_id = l.screen_template_id
             JOIN grp ON grp.object_group_id = l.object_group_id AND grp.object_alias = stmpl.sta_object_alias
          WHERE 1 = 1
        ), tmp_sever_max AS (
         SELECT s.schema_src_id,
            s.table_src_id,
            s.screen_template_id,
            max(s.priority_src_id) AS severity,
            max(s.priority_src_id)::real / count(*)::real AS severity_max
           FROM tmp_screen s
          WHERE 1 = 1 AND s.priority_src_id IS NOT NULL
          GROUP BY s.schema_src_id, s.table_src_id, s.screen_template_id
        ), tmp_sever AS (
         SELECT f.load_dttm::date AS start_dt,
            f.screen_id,
            f.schema_src_id,
            f.table_src_id,
            sum(f.final_severity_score) AS severity
           FROM s_grnplm_as_cib_gm_dg.meta_error_event_fact f
          WHERE 1 = 1 AND f.load_dttm::date > (now()::date - '10 days'::interval)::date
          GROUP BY f.load_dttm::date, f.screen_id, f.schema_src_id, f.table_src_id
        )
 SELECT s1.screen_id,
    s1.screen_template_id,
    s1.object_group_id,
    s1.screen_category,
    s1.descr,
    s1.screen_sql,
    s1.sta_object_alias,
    s1.sta_attribute_src_id,
    s1.object_group_name,
    s1.object_group_descr,
    s1.object_id,
    COALESCE(s1.schema_src_id, p.schema_src_id::character varying) AS schema_src_id,
    COALESCE(s1.table_src_id, p.node_src_id::character varying) AS table_src_id,
    s1.attribute_src_id,
    s1.object_alias,
    s1.priority_src_id,
    s1.priority_cd,
    s1.priority_nm,
    s2.severity_max,
    COALESCE(p.plan_dt, now()::date) AS plan_dt,
    s3.severity
   FROM tmp_screen s1
     FULL JOIN dg_full.meta_scheduler_plan p ON s1.schema_src_id::text = p.schema_src_id AND s1.table_src_id::text = p.node_src_id
     LEFT JOIN tmp_sever_max s2 ON s1.schema_src_id::text = s2.schema_src_id::text AND s1.table_src_id::text = s2.table_src_id::text AND s1.screen_template_id = s2.screen_template_id AND s1.priority_src_id = s2.severity
     LEFT JOIN tmp_sever s3 ON s1.schema_src_id::text = s3.schema_src_id::text AND s1.table_src_id::text = s3.table_src_id::text AND s1.screen_id = s3.screen_id AND COALESCE(p.plan_dt, now()::date) = s3.start_dt
  WHERE 1 = 1 AND p.plan_dt >= (now()::date - '10 days'::interval)::date;


-- dg_full.vmeta_screen_link source

CREATE OR REPLACE VIEW dg_full.vmeta_screen_link
AS SELECT m.screen_id,
    m.screen_template_id,
    m.object_group_id,
    m.processing_order,
    m.etl_stage,
    m.default_severity_score,
    m.is_active,
    m.eff_from_dt,
    m.eff_to_dt,
    m.load_dttm,
    m.wf_load_id,
    m.src_cd,
    m.period_run,
    m.exception_group_id
   FROM dg_full.meta_screen_link_manual m
UNION
 SELECT l.screen_id,
    l.screen_template_id,
    l.object_group_id,
    l.processing_order,
    l.etl_stage,
    l.default_severity_score,
    l.is_active,
    l.eff_from_dt,
    l.eff_to_dt,
    l.load_dttm,
    l.wf_load_id,
    l.src_cd,
    l.period_run,
    l.exception_group_id
   FROM dg_full.meta_screen_link l;


-- dg_full.vmeta_search_graph source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph
AS WITH RECURSIVE search_graph(src_schema_src_id, src_node_src_id, target_schema_src_id, target_node_src_id, src_node_id, target_node_id, weight, depth, path, cycle) AS (
         SELECT g.src_schema_src_id,
            g.src_node_src_id,
            g.target_schema_src_id,
            g.target_node_src_id,
            (g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text AS src_node_id,
            (g.target_schema_src_id::text || '||'::text) || g.target_node_src_id::text AS target_node_id,
            g.weight,
            1 AS depth,
            ARRAY[(g.target_schema_src_id::text || '||'::text) || g.target_node_src_id::text, (g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text] AS path,
            false AS cycle
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1 AND g.is_active = true
        UNION ALL
         SELECT g.src_schema_src_id,
            g.src_node_src_id,
            g.target_schema_src_id,
            g.target_node_src_id,
            (g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text AS src_node_id,
            (g.target_schema_src_id::text || '||'::text) || g.target_node_src_id::text AS target_node_id,
            g.weight,
            sg_1.depth + 1 AS depth,
            sg_1.path || ((g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text),
            ((g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text) = ANY (sg_1.path)
           FROM dg_full.meta_edge_link g,
            search_graph sg_1
          WHERE 1 = 1 AND g.target_node_id = sg_1.src_node_id AND NOT sg_1.cycle
        )
 SELECT sg.src_schema_src_id::name AS src_schema_src_id,
    ss.descr AS ss_descr,
    ss.type AS ss_type,
    ss.schema_type AS ss_schema_type,
    ss.src_cd AS ss_src_cd,
    sg.src_node_src_id::name AS src_node_src_id,
    sn.node_type_src_id AS snt_node_type_src_id,
    snt.node_type_cd AS snt_node_type_cd,
    snt.descr AS snt_descr,
    sg.target_schema_src_id::name AS target_schema_src_id,
    ts.type AS ts_type,
    ts.schema_type AS ts_schema_type,
    ts.src_cd AS ts_src_cd,
    ts.descr AS ts_descr,
    sg.target_node_src_id::name AS target_node_src_id,
    tn.node_type_src_id AS tnt_node_type_src_id,
    tnt.node_type_cd AS tnt_node_type_cd,
    tnt.descr AS tnt_descr,
    sg.src_node_id,
    sg.target_node_id,
    sg.weight::integer AS weight,
    sg.depth,
    sg.path,
    sg.cycle,
    COALESCE(src_o.property_val::integer, 0) + COALESCE(tgt_o.property_val::integer, 0) AS is_active
   FROM search_graph sg
     JOIN dg_full.meta_schema_ref_table ss ON sg.src_schema_src_id::name = ss.schema_src_id::name
     JOIN dg_full.meta_schema_ref_table ts ON sg.target_schema_src_id::name = ts.schema_src_id::name
     LEFT JOIN dg_full.meta_node_ref_table sn ON sg.src_schema_src_id::text = sn.schema_src_id::text AND sg.src_node_src_id::text = sn.node_src_id::text
     LEFT JOIN dg_full.meta_node_type_ref_table snt ON sn.node_type_src_id = snt.node_type_src_id
     LEFT JOIN dg_full.meta_node_ref_table tn ON sg.target_schema_src_id::text = tn.schema_src_id::text AND sg.target_node_src_id::text = tn.node_src_id::text
     LEFT JOIN dg_full.meta_node_type_ref_table tnt ON tn.node_type_src_id = tnt.node_type_src_id
     LEFT JOIN dg_full.vmeta_property_hsat src_o ON src_o.property_type_src_id = 6 AND src_o.schema_src_id::name = sg.src_schema_src_id::name AND src_o.object_src_id::name = sg.src_node_src_id::name
     LEFT JOIN dg_full.vmeta_property_hsat tgt_o ON tgt_o.property_type_src_id = 6 AND tgt_o.schema_src_id::name = sg.target_schema_src_id::name AND tgt_o.object_src_id::name = sg.target_node_src_id::name;


-- dg_full.vmeta_search_graph_level_based source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_level_based
AS SELECT g.target_schema_src_id AS root_schema_src_id,
    g.target_node_src_id AS root_node_src_id,
    g.src_cd::text AS root_src_cd,
    g.tgt_node_type_cd AS root_node_type_cd,
    COALESCE(g1.target_schema_src_id, g.src_schema_src_id) AS l1_schema_id,
    COALESCE(g1.target_node_src_id, g.src_node_src_id) AS l1_node_id,
    COALESCE(g1.tgt_node_type_cd, g.src_node_type_cd) AS l1_node_type_cd,
    COALESCE(g2.target_schema_src_id, g1.src_schema_src_id) AS l2_schema_id,
    COALESCE(g2.target_node_src_id, g1.src_node_src_id) AS l2_node_id,
    COALESCE(g2.tgt_node_type_cd, g1.src_node_type_cd) AS l2_node_type_cd,
    COALESCE(g3.target_schema_src_id, g2.src_schema_src_id) AS l3_schema_id,
    COALESCE(g3.target_node_src_id, g2.src_node_src_id) AS l3_node_id,
    COALESCE(g3.tgt_node_type_cd, g2.src_node_type_cd) AS l3_node_type_cd,
    COALESCE(g4.target_schema_src_id, g3.src_schema_src_id) AS l4_schema_id,
    COALESCE(g4.target_node_src_id, g3.src_node_src_id) AS l4_node_id,
    COALESCE(g4.tgt_node_type_cd, g3.src_node_type_cd) AS l4_node_type_cd,
    COALESCE(g5.target_schema_src_id, g4.src_schema_src_id) AS l5_schema_id,
    COALESCE(g5.target_node_src_id, g4.src_node_src_id) AS l5_node_id,
    COALESCE(g5.tgt_node_type_cd, g4.src_node_type_cd) AS l5_node_type_cd,
    COALESCE(g6.target_schema_src_id, g5.src_schema_src_id) AS l6_schema_id,
    COALESCE(g6.target_node_src_id, g5.src_node_src_id) AS l6_node_id,
    COALESCE(g6.tgt_node_type_cd, g5.src_node_type_cd) AS l6_node_type_cd,
    COALESCE(g7.target_schema_src_id, g6.src_schema_src_id) AS l7_schema_id,
    COALESCE(g7.target_node_src_id, g6.src_node_src_id) AS l7_node_id,
    COALESCE(g7.tgt_node_type_cd, g6.src_node_type_cd) AS l7_node_type_cd,
    COALESCE(g8.target_schema_src_id, g7.src_schema_src_id) AS l8_schema_id,
    COALESCE(g8.target_node_src_id, g7.src_node_src_id) AS l8_node_id,
    COALESCE(g8.tgt_node_type_cd, g7.src_node_type_cd) AS l8_node_type_cd,
    COALESCE(g9.target_schema_src_id, g8.src_schema_src_id) AS l9_schema_id,
    COALESCE(g9.target_node_src_id, g8.src_node_src_id) AS l9_node_id,
    COALESCE(g9.tgt_node_type_cd, g8.src_node_type_cd) AS l9_node_type_cd,
    COALESCE(g10.target_schema_src_id, g9.src_schema_src_id) AS l10_schema_id,
    COALESCE(g10.target_node_src_id, g9.src_node_src_id) AS l10_node_id,
    COALESCE(g10.tgt_node_type_cd, g9.src_node_type_cd) AS l10_node_type_cd
   FROM dg_full.meta_edge_link g
     LEFT JOIN dg_full.meta_edge_link g1 ON g.src_node_src_id::text = g1.target_node_src_id::text AND g.src_schema_src_id::text = g1.target_schema_src_id::text AND g.src_node_type_cd = g1.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g2 ON g1.src_node_src_id::text = g2.target_node_src_id::text AND g1.src_schema_src_id::text = g2.target_schema_src_id::text AND g1.src_node_type_cd = g2.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g3 ON g2.src_node_src_id::text = g3.target_node_src_id::text AND g2.src_schema_src_id::text = g3.target_schema_src_id::text AND g2.src_node_type_cd = g3.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g4 ON g3.src_node_src_id::text = g4.target_node_src_id::text AND g3.src_schema_src_id::text = g4.target_schema_src_id::text AND g3.src_node_type_cd = g4.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g5 ON g4.src_node_src_id::text = g5.target_node_src_id::text AND g4.src_schema_src_id::text = g5.target_schema_src_id::text AND g4.src_node_type_cd = g5.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g6 ON g5.src_node_src_id::text = g6.target_node_src_id::text AND g5.src_schema_src_id::text = g6.target_schema_src_id::text AND g5.src_node_type_cd = g6.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g7 ON g6.src_node_src_id::text = g7.target_node_src_id::text AND g6.src_schema_src_id::text = g7.target_schema_src_id::text AND g6.src_node_type_cd = g7.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g8 ON g7.src_node_src_id::text = g8.target_node_src_id::text AND g7.src_schema_src_id::text = g8.target_schema_src_id::text AND g7.src_node_type_cd = g8.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g9 ON g8.src_node_src_id::text = g9.target_node_src_id::text AND g8.src_schema_src_id::text = g9.target_schema_src_id::text AND g8.src_node_type_cd = g9.tgt_node_type_cd
     LEFT JOIN dg_full.meta_edge_link g10 ON g9.src_node_src_id::text = g10.target_node_src_id::text AND g9.src_schema_src_id::text = g10.target_schema_src_id::text AND g9.src_node_type_cd = g10.tgt_node_type_cd
  WHERE 1 = 1 AND g.src_schema_src_id::text !~~ '%_ld_%'::text AND (g.src_schema_src_id::text <> ALL (ARRAY['s_grnplm_as_cib_gm_meta'::text])) AND g.target_schema_src_id::text !~~ '%_ld_%'::text AND (g.target_schema_src_id::text <> ALL (ARRAY['s_grnplm_as_cib_gm_meta'::text]))
  GROUP BY g.target_schema_src_id, g.target_node_src_id, g.src_cd::text, g.tgt_node_type_cd, COALESCE(g1.target_schema_src_id, g.src_schema_src_id), COALESCE(g1.target_node_src_id, g.src_node_src_id), COALESCE(g1.tgt_node_type_cd, g.src_node_type_cd), COALESCE(g2.target_schema_src_id, g1.src_schema_src_id), COALESCE(g2.target_node_src_id, g1.src_node_src_id), COALESCE(g2.tgt_node_type_cd, g1.src_node_type_cd), COALESCE(g3.target_schema_src_id, g2.src_schema_src_id), COALESCE(g3.target_node_src_id, g2.src_node_src_id), COALESCE(g3.tgt_node_type_cd, g2.src_node_type_cd), COALESCE(g4.target_schema_src_id, g3.src_schema_src_id), COALESCE(g4.target_node_src_id, g3.src_node_src_id), COALESCE(g4.tgt_node_type_cd, g3.src_node_type_cd), COALESCE(g5.target_schema_src_id, g4.src_schema_src_id), COALESCE(g5.target_node_src_id, g4.src_node_src_id), COALESCE(g5.tgt_node_type_cd, g4.src_node_type_cd), COALESCE(g6.target_schema_src_id, g5.src_schema_src_id), COALESCE(g6.target_node_src_id, g5.src_node_src_id), COALESCE(g6.tgt_node_type_cd, g5.src_node_type_cd), COALESCE(g7.target_schema_src_id, g6.src_schema_src_id), COALESCE(g7.target_node_src_id, g6.src_node_src_id), COALESCE(g7.tgt_node_type_cd, g6.src_node_type_cd), COALESCE(g8.target_schema_src_id, g7.src_schema_src_id), COALESCE(g8.target_node_src_id, g7.src_node_src_id), COALESCE(g8.tgt_node_type_cd, g7.src_node_type_cd), COALESCE(g9.target_schema_src_id, g8.src_schema_src_id), COALESCE(g9.target_node_src_id, g8.src_node_src_id), COALESCE(g9.tgt_node_type_cd, g8.src_node_type_cd), COALESCE(g10.target_schema_src_id, g9.src_schema_src_id), COALESCE(g10.target_node_src_id, g9.src_node_src_id), COALESCE(g10.tgt_node_type_cd, g9.src_node_type_cd);


-- dg_full.vmeta_search_graph_level_based7 source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_level_based7
AS WITH tmp_obj AS (
         SELECT g_1.target_schema_src_id,
            g_1.target_node_src_id,
            g_1.src_cd::text AS src_cd,
            g_1.tgt_node_type_cd,
            g_1.src_schema_src_id,
            g_1.src_node_src_id,
            g_1.src_node_type_cd,
            g_1.wf_load_id,
            g_1.load_dttm
           FROM s_grnplm_as_cib_gm_dg.meta_edge_link g_1
          WHERE 1 = 1 AND g_1.target_schema_src_id::text !~~ '%_ld_%'::text AND g_1.src_schema_src_id::text !~~ '%_ld_%'::text
        ), tmp_trg AS (
         SELECT g_1.target_schema_src_id,
            g_1.target_node_src_id,
            g_1.src_cd::text AS src_cd,
            g_1.tgt_node_type_cd,
            g_1.src_schema_src_id,
            g_1.src_node_src_id,
            g_1.src_node_type_cd,
            g_1.wf_load_id,
            g_1.load_dttm
           FROM s_grnplm_as_cib_gm_dg.meta_edge_link g_1
          WHERE 1 = 1 AND g_1.target_schema_src_id::text !~~ '%_ld_%'::text AND g_1.src_schema_src_id::text !~~ '%_ld_%'::text AND g_1.src_node_type_cd = 'Entity'::text AND g_1.tgt_node_type_cd = 'Flow'::text
        ), tt AS (
         SELECT g.target_schema_src_id::text AS root_schema_src_id,
            g.target_node_src_id::text AS root_node_src_id,
            g.src_cd AS root_src_cd,
            g.tgt_node_type_cd AS root_node_type_cd,
            COALESCE(g1.target_schema_src_id, g.src_schema_src_id)::text AS l1_schema_id,
            COALESCE(g1.target_node_src_id, g.src_node_src_id)::text AS l1_node_id,
            COALESCE(g1.tgt_node_type_cd, g.src_node_type_cd) AS l1_node_type_cd,
            COALESCE(g2.target_schema_src_id, g1.src_schema_src_id)::text AS l2_schema_id,
            COALESCE(g2.target_node_src_id, g1.src_node_src_id)::text AS l2_node_id,
            COALESCE(g2.tgt_node_type_cd, g1.src_node_type_cd) AS l2_node_type_cd,
            COALESCE(g3.target_schema_src_id, g2.src_schema_src_id)::text AS l3_schema_id,
            COALESCE(g3.target_node_src_id, g2.src_node_src_id)::text AS l3_node_id,
            COALESCE(g3.tgt_node_type_cd, g2.src_node_type_cd) AS l3_node_type_cd,
            COALESCE(g4.target_schema_src_id, g3.src_schema_src_id)::text AS l4_schema_id,
            COALESCE(g4.target_node_src_id, g3.src_node_src_id)::text AS l4_node_id,
            COALESCE(g4.tgt_node_type_cd, g3.src_node_type_cd) AS l4_node_type_cd,
            COALESCE(g5.target_schema_src_id, g4.src_schema_src_id)::text AS l5_schema_id,
            COALESCE(g5.target_node_src_id, g4.src_node_src_id)::text AS l5_node_id,
            COALESCE(g5.tgt_node_type_cd, g4.src_node_type_cd) AS l5_node_type_cd,
            COALESCE(g6.target_schema_src_id, g5.src_schema_src_id)::text AS l6_schema_id,
            COALESCE(g6.target_node_src_id, g5.src_node_src_id)::text AS l6_node_id,
            COALESCE(g6.tgt_node_type_cd, g5.src_node_type_cd) AS l6_node_type_cd,
            NULL::text AS l7_schema_id,
            NULL::text AS l7_node_id,
            NULL::text AS l7_node_type_cd,
            NULL::text AS l8_schema_id,
            NULL::text AS l8_node_id,
            NULL::text AS l8_node_type_cd,
            NULL::text AS l9_schema_id,
            NULL::text AS l9_node_id,
            NULL::text AS l9_node_type_cd,
            NULL::text AS l10_schema_id,
            NULL::text AS l10_node_id,
            NULL::text AS l10_node_type_cd
           FROM tmp_obj g
             LEFT JOIN tmp_obj g1 ON g.src_node_src_id::text = g1.target_node_src_id::text AND g.src_schema_src_id::text = g1.target_schema_src_id::text AND g.src_node_type_cd = g1.tgt_node_type_cd
             LEFT JOIN tmp_obj g2 ON g1.src_node_src_id::text = g2.target_node_src_id::text AND g1.src_schema_src_id::text = g2.target_schema_src_id::text AND g1.src_node_type_cd = g2.tgt_node_type_cd
             LEFT JOIN tmp_obj g3 ON g2.src_node_src_id::text = g3.target_node_src_id::text AND g2.src_schema_src_id::text = g3.target_schema_src_id::text AND g2.src_node_type_cd = g3.tgt_node_type_cd
             LEFT JOIN tmp_obj g4 ON g3.src_node_src_id::text = g4.target_node_src_id::text AND g3.src_schema_src_id::text = g4.target_schema_src_id::text AND g3.src_node_type_cd = g4.tgt_node_type_cd
             LEFT JOIN tmp_obj g5 ON g4.src_node_src_id::text = g5.target_node_src_id::text AND g4.src_schema_src_id::text = g5.target_schema_src_id::text AND g4.src_node_type_cd = g5.tgt_node_type_cd
             LEFT JOIN tmp_obj g6 ON g5.src_node_src_id::text = g6.target_node_src_id::text AND g5.src_schema_src_id::text = g6.target_schema_src_id::text AND g5.src_node_type_cd = g6.tgt_node_type_cd
          WHERE 1 = 1 AND (g.tgt_node_type_cd = ANY (ARRAY['Table'::text, 'View'::text, 'Function'::text]))
          GROUP BY g.target_schema_src_id::text, g.target_node_src_id::text, g.src_cd, g.tgt_node_type_cd, COALESCE(g1.target_schema_src_id, g.src_schema_src_id)::text, COALESCE(g1.target_node_src_id, g.src_node_src_id)::text, COALESCE(g1.tgt_node_type_cd, g.src_node_type_cd), COALESCE(g2.target_schema_src_id, g1.src_schema_src_id)::text, COALESCE(g2.target_node_src_id, g1.src_node_src_id)::text, COALESCE(g2.tgt_node_type_cd, g1.src_node_type_cd), COALESCE(g3.target_schema_src_id, g2.src_schema_src_id)::text, COALESCE(g3.target_node_src_id, g2.src_node_src_id)::text, COALESCE(g3.tgt_node_type_cd, g2.src_node_type_cd), COALESCE(g4.target_schema_src_id, g3.src_schema_src_id)::text, COALESCE(g4.target_node_src_id, g3.src_node_src_id)::text, COALESCE(g4.tgt_node_type_cd, g3.src_node_type_cd), COALESCE(g5.target_schema_src_id, g4.src_schema_src_id)::text, COALESCE(g5.target_node_src_id, g4.src_node_src_id)::text, COALESCE(g5.tgt_node_type_cd, g4.src_node_type_cd), COALESCE(g6.target_schema_src_id, g5.src_schema_src_id)::text, COALESCE(g6.target_node_src_id, g5.src_node_src_id)::text, COALESCE(g6.tgt_node_type_cd, g5.src_node_type_cd), NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text, NULL::text
        )
 SELECT tt.root_schema_src_id,
    tt.root_node_src_id,
    tt.root_src_cd,
    tt.root_node_type_cd,
    tt.l1_schema_id,
    tt.l1_node_id,
    tt.l1_node_type_cd,
    tt.l2_schema_id,
    tt.l2_node_id,
    tt.l2_node_type_cd,
    tt.l3_schema_id,
    tt.l3_node_id,
    tt.l3_node_type_cd,
    tt.l4_schema_id,
    tt.l4_node_id,
    tt.l4_node_type_cd,
    tt.l5_schema_id,
    tt.l5_node_id,
    tt.l5_node_type_cd,
    tt.l6_schema_id,
    tt.l6_node_id,
    tt.l6_node_type_cd,
    tt.l7_schema_id,
    tt.l7_node_id,
    tt.l7_node_type_cd,
    tt.l8_schema_id,
    tt.l8_node_id,
    tt.l8_node_type_cd,
    tt.l9_schema_id,
    tt.l9_node_id,
    tt.l9_node_type_cd,
    tt.l10_schema_id,
    tt.l10_node_id,
    tt.l10_node_type_cd,
        CASE
            WHEN t1.src_node_src_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END AS is_trigger1,
        CASE
            WHEN t2.src_node_src_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END AS is_trigger2,
        CASE
            WHEN t3.src_node_src_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END AS is_trigger3,
        CASE
            WHEN t4.src_node_src_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END AS is_trigger4,
        CASE
            WHEN t5.src_node_src_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END AS is_trigger5,
        CASE
            WHEN t6.src_node_src_id IS NOT NULL THEN 1
            ELSE NULL::integer
        END AS is_trigger6
   FROM tt
     LEFT JOIN tmp_trg t1 ON t1.src_node_src_id::text = tt.l1_node_id AND tt.l1_node_type_cd = 'Table'::text
     LEFT JOIN tmp_trg t2 ON t2.src_node_src_id::text = tt.l2_node_id AND tt.l2_node_type_cd = 'Table'::text
     LEFT JOIN tmp_trg t3 ON t3.src_node_src_id::text = tt.l3_node_id AND tt.l3_node_type_cd = 'Table'::text
     LEFT JOIN tmp_trg t4 ON t4.src_node_src_id::text = tt.l4_node_id AND tt.l4_node_type_cd = 'Table'::text
     LEFT JOIN tmp_trg t5 ON t5.src_node_src_id::text = tt.l5_node_id AND tt.l5_node_type_cd = 'Table'::text
     LEFT JOIN tmp_trg t6 ON t6.src_node_src_id::text = tt.l6_node_id AND tt.l6_node_type_cd = 'Table'::text;


-- dg_full.vmeta_search_graph_level_based_app source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_level_based_app
AS SELECT g.target_schema_src_id AS root_schema_src_id,
    g.target_node_src_id AS root_node_src_id,
    g.src_cd::text AS root_src_cd,
    g.tgt_node_type_cd AS root_node_type_cd,
    COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_schema_src_id
            ELSE NULL::character varying
        END) AS src_schema_id,
    COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_src_id
            ELSE NULL::character varying
        END) AS src_node_id,
    COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_type_cd
            ELSE NULL::text
        END) AS src_node_type_cd
   FROM dg_full.meta_edge_link g
     LEFT JOIN dg_full.meta_edge_link g1 ON g.src_node_src_id::text = g1.target_node_src_id::text AND g.src_schema_src_id::text = g1.target_schema_src_id::text AND g.src_node_type_cd = g1.tgt_node_type_cd AND (g1.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g2 ON g1.src_node_src_id::text = g2.target_node_src_id::text AND g1.src_schema_src_id::text = g2.target_schema_src_id::text AND g1.src_node_type_cd = g2.tgt_node_type_cd AND (g2.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g3 ON g2.src_node_src_id::text = g3.target_node_src_id::text AND g2.src_schema_src_id::text = g3.target_schema_src_id::text AND g2.src_node_type_cd = g3.tgt_node_type_cd AND (g3.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g4 ON g3.src_node_src_id::text = g4.target_node_src_id::text AND g3.src_schema_src_id::text = g4.target_schema_src_id::text AND g3.src_node_type_cd = g4.tgt_node_type_cd AND (g4.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g5 ON g4.src_node_src_id::text = g5.target_node_src_id::text AND g4.src_schema_src_id::text = g5.target_schema_src_id::text AND g4.src_node_type_cd = g5.tgt_node_type_cd AND (g5.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g6 ON g5.src_node_src_id::text = g6.target_node_src_id::text AND g5.src_schema_src_id::text = g6.target_schema_src_id::text AND g5.src_node_type_cd = g6.tgt_node_type_cd AND (g6.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g7 ON g6.src_node_src_id::text = g7.target_node_src_id::text AND g6.src_schema_src_id::text = g7.target_schema_src_id::text AND g6.src_node_type_cd = g7.tgt_node_type_cd AND (g7.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g8 ON g7.src_node_src_id::text = g8.target_node_src_id::text AND g7.src_schema_src_id::text = g8.target_schema_src_id::text AND g7.src_node_type_cd = g8.tgt_node_type_cd AND (g8.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g9 ON g8.src_node_src_id::text = g9.target_node_src_id::text AND g8.src_schema_src_id::text = g9.target_schema_src_id::text AND g8.src_node_type_cd = g9.tgt_node_type_cd AND (g9.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
  WHERE 1 = 1 AND (g.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text])) AND NOT ((g.target_schema_src_id::text, g.target_node_src_id::text) IN ( SELECT t.src_schema_src_id,
            t.src_node_src_id
           FROM dg_full.meta_edge_link t)) AND g.src_schema_src_id::text !~~ '%_ld_%'::text AND (g.src_schema_src_id::text <> ALL (ARRAY['s_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text])) AND g.target_schema_src_id::text !~~ '%_ld_%'::text AND (g.target_schema_src_id::text <> ALL (ARRAY['s_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text]))
  GROUP BY g.target_schema_src_id, g.target_node_src_id, g.src_cd::text, g.tgt_node_type_cd, COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_schema_src_id
            ELSE NULL::character varying
        END), COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_src_id
            ELSE NULL::character varying
        END), COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_type_cd
            ELSE NULL::text
        END);


-- dg_full.vmeta_search_graph_level_based_app_lg source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_level_based_app_lg
AS SELECT g.target_schema_src_id AS root_schema_src_id,
    g.target_node_src_id AS root_node_src_id,
    g.src_cd::text AS root_src_cd,
    g.tgt_node_type_cd AS root_node_type_cd,
    COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_schema_src_id
            ELSE NULL::character varying
        END) AS src_schema_id,
    COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_src_id
            ELSE NULL::character varying
        END) AS src_node_id,
    COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_type_cd
            ELSE NULL::text
        END) AS src_node_type_cd
   FROM dg_full.meta_edge_link g
     LEFT JOIN dg_full.meta_edge_link g1 ON g.src_node_src_id::text = g1.target_node_src_id::text AND g.src_schema_src_id::text = g1.target_schema_src_id::text AND g.src_node_type_cd = g1.tgt_node_type_cd AND (g1.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g2 ON g1.src_node_src_id::text = g2.target_node_src_id::text AND g1.src_schema_src_id::text = g2.target_schema_src_id::text AND g1.src_node_type_cd = g2.tgt_node_type_cd AND (g2.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g3 ON g2.src_node_src_id::text = g3.target_node_src_id::text AND g2.src_schema_src_id::text = g3.target_schema_src_id::text AND g2.src_node_type_cd = g3.tgt_node_type_cd AND (g3.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g4 ON g3.src_node_src_id::text = g4.target_node_src_id::text AND g3.src_schema_src_id::text = g4.target_schema_src_id::text AND g3.src_node_type_cd = g4.tgt_node_type_cd AND (g4.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g5 ON g4.src_node_src_id::text = g5.target_node_src_id::text AND g4.src_schema_src_id::text = g5.target_schema_src_id::text AND g4.src_node_type_cd = g5.tgt_node_type_cd AND (g5.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g6 ON g5.src_node_src_id::text = g6.target_node_src_id::text AND g5.src_schema_src_id::text = g6.target_schema_src_id::text AND g5.src_node_type_cd = g6.tgt_node_type_cd AND (g6.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g7 ON g6.src_node_src_id::text = g7.target_node_src_id::text AND g6.src_schema_src_id::text = g7.target_schema_src_id::text AND g6.src_node_type_cd = g7.tgt_node_type_cd AND (g7.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g8 ON g7.src_node_src_id::text = g8.target_node_src_id::text AND g7.src_schema_src_id::text = g8.target_schema_src_id::text AND g7.src_node_type_cd = g8.tgt_node_type_cd AND (g8.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
     LEFT JOIN dg_full.meta_edge_link g9 ON g8.src_node_src_id::text = g9.target_node_src_id::text AND g8.src_schema_src_id::text = g9.target_schema_src_id::text AND g8.src_node_type_cd = g9.tgt_node_type_cd AND (g9.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'QVD'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]))
  WHERE 1 = 1 AND (g.tgt_node_type_cd = ANY (ARRAY['TFS'::text, 'Dashboard QS'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text])) AND NOT ((g.target_schema_src_id::text, g.target_node_src_id::text) IN ( SELECT t.src_schema_src_id,
            t.src_node_src_id
           FROM dg_full.meta_edge_link t)) AND g.src_schema_src_id::text !~~ '%_ld_%'::text AND (g.src_schema_src_id::text <> ALL (ARRAY['s_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text])) AND g.target_schema_src_id::text !~~ '%_ld_%'::text AND (g.target_schema_src_id::text <> ALL (ARRAY['s_grnplm_as_cib_gm_meta'::text, 's_grnplm_as_cib_gm_dg'::text, 's_grnplm_as_cib_gm_mart_dg'::text]))
  GROUP BY g.target_schema_src_id, g.target_node_src_id, g.src_cd::text, g.tgt_node_type_cd, COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_schema_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_schema_src_id
            ELSE NULL::character varying
        END), COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_src_id
            ELSE NULL::character varying
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_src_id
            ELSE NULL::character varying
        END), COALESCE(
        CASE
            WHEN g.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g1.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g1.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g2.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g2.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g3.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g3.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g4.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g4.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g5.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g5.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g6.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g6.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g7.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g7.src_node_type_cd
            ELSE NULL::text
        END,
        CASE
            WHEN g8.src_node_type_cd <> ALL (ARRAY['TFS'::text, 'Dashboard QS'::text, 'QVD'::text, 'Application QS'::text, 'SMD'::text, 'Application Navi'::text]) THEN g8.src_node_type_cd
            ELSE NULL::text
        END);


-- dg_full.vmeta_search_graph_target source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_target
AS WITH RECURSIVE search_graph(src_schema_src_id, src_node_src_id, target_schema_src_id, target_node_src_id, src_node_id, target_node_id, depth, path, cycle) AS (
         SELECT g.src_schema_src_id,
            g.src_node_src_id,
            g.target_schema_src_id,
            g.target_node_src_id,
            (g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text AS src_node_id,
            (g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text AS target_node_id,
            1 AS depth,
            ARRAY[(g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text, (g.src_schema_src_id::text || '.'::text) || g.src_node_src_id::text] AS path,
            false AS cycle,
            (g.target_schema_src_id::text || '.'::text) || g.target_node_src_id::text AS root_node_id
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1 AND (g.target_schema_src_id::text ~~ 's_grnplm_as_cib_gm_mart_tib%'::text OR g.target_schema_src_id::text ~~ 's_grnplm_as_cib_gm_ods_%'::text) AND g.src_cd::text = 'GP'::text AND g.tgt_node_type_cd <> 'Function'::text
        UNION ALL
         SELECT nxt.src_schema_src_id,
            nxt.src_node_src_id,
            nxt.target_schema_src_id,
            nxt.target_node_src_id,
            (nxt.src_schema_src_id::text || '.'::text) || nxt.src_node_src_id::text AS src_node_id,
            (nxt.target_schema_src_id::text || '.'::text) || nxt.target_node_src_id::text AS target_node_id,
            prv.depth + 1 AS depth,
            prv.path || ((nxt.src_schema_src_id::text || '.'::text) || nxt.src_node_src_id::text),
            ((nxt.src_schema_src_id::text || '.'::text) || nxt.src_node_src_id::text) = ANY (prv.path),
            prv.root_node_id
           FROM search_graph prv
             JOIN dg_full.meta_edge_link nxt ON lower(prv.src_node_id) = lower(nxt.target_node_id)
          WHERE 1 = 1 AND nxt.src_cd::text = 'GP'::text AND NOT prv.cycle
        ), temp_sql_2 AS (
         SELECT replace(replace(replace(temp_sql.src_node_id, '://'::text, '.'::text), '/'::text, '.'::text), ' '::text, '.'::text) AS node_id,
            temp_sql.depth,
            temp_sql.root_node_id
           FROM search_graph temp_sql
        UNION ALL
         SELECT replace(replace(replace(temp_sql.target_node_id, '://'::text, '.'::text), '/'::text, '.'::text), ' '::text, '.'::text) AS node_id,
            temp_sql.depth,
            temp_sql.root_node_id
           FROM search_graph temp_sql
        )
 SELECT temp_sql_2.node_id,
    sn.node_type_cd,
    sn.src_cd::text AS src_cd,
    min(temp_sql_2.depth) AS depth,
    temp_sql_2.root_node_id,
    tn.node_type_cd AS root_node_type_cd
   FROM temp_sql_2
     LEFT JOIN dg_full.meta_node_ref_table sn ON temp_sql_2.node_id = ((sn.schema_src_id::text || '.'::text) || sn.node_src_id::text)
     LEFT JOIN dg_full.meta_node_ref_table tn ON temp_sql_2.root_node_id = ((tn.schema_src_id::text || '.'::text) || tn.node_src_id::text)
  WHERE 1 = 1 AND temp_sql_2.node_id <> temp_sql_2.root_node_id AND temp_sql_2.node_id !~~ '%_meta.%'::text
  GROUP BY temp_sql_2.node_id, sn.node_type_cd, sn.src_cd, temp_sql_2.root_node_id, tn.node_type_cd;


-- dg_full.vmeta_search_graph_target_chain source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_target_chain
AS WITH RECURSIVE search_graph(src_schema_src_id, src_node_src_id, target_schema_src_id, target_node_src_id, src_node_id, target_node_id, depth, path, cycle) AS (
         SELECT g.src_schema_src_id,
            g.src_node_src_id,
            g.target_schema_src_id,
            g.target_node_src_id,
            (g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text AS src_node_id,
            (g.target_schema_src_id::text || '||'::text) || g.target_node_src_id::text AS target_node_id,
            1 AS depth,
            ARRAY[(g.target_schema_src_id::text || '||'::text) || g.target_node_src_id::text, (g.src_schema_src_id::text || '||'::text) || g.src_node_src_id::text] AS path,
            false AS cycle,
            (g.target_schema_src_id::text || '||'::text) || g.target_node_src_id::text AS root_node_id
           FROM dg_full.meta_edge_link g
          WHERE 1 = 1
        UNION ALL
         SELECT nxt.src_schema_src_id,
            nxt.src_node_src_id,
            nxt.target_schema_src_id,
            nxt.target_node_src_id,
            (nxt.src_schema_src_id::text || '||'::text) || nxt.src_node_src_id::text AS src_node_id,
            (nxt.target_schema_src_id::text || '||'::text) || nxt.target_node_src_id::text AS target_node_id,
            prv.depth + 1 AS depth,
            prv.path || ((nxt.src_schema_src_id::text || '||'::text) || nxt.src_node_src_id::text),
            ((nxt.src_schema_src_id::text || '||'::text) || nxt.src_node_src_id::text) = ANY (prv.path),
            prv.root_node_id
           FROM search_graph prv
             JOIN dg_full.meta_edge_link nxt ON lower(prv.src_node_id) = lower(nxt.target_node_id)
          WHERE 1 = 1 AND NOT prv.cycle
        ), temp_sql_2 AS (
         SELECT replace(replace(replace(temp_sql.src_node_id, '://'::text, '||'::text), '/'::text, '||'::text), ' '::text, '||'::text) AS src_node_id,
            replace(replace(replace(temp_sql.target_node_id, '://'::text, '||'::text), '/'::text, '||'::text), ' '::text, '||'::text) AS target_node_id,
            temp_sql.depth,
            temp_sql.root_node_id
           FROM search_graph temp_sql
        )
 SELECT temp_sql_2.src_node_id,
    sn.node_type_cd AS src_node_type_cd,
    sn.src_cd::text AS src_src_cd,
    temp_sql_2.target_node_id,
    tn.node_type_cd AS taget_node_type_cd,
    tn.src_cd::text AS target_src_cd,
    min(temp_sql_2.depth) AS depth,
    temp_sql_2.root_node_id,
    rn.node_type_cd AS root_node_type_cd
   FROM temp_sql_2
     LEFT JOIN dg_full.meta_node_ref_table sn ON temp_sql_2.src_node_id = ((sn.schema_src_id::text || '||'::text) || sn.node_src_id::text)
     LEFT JOIN dg_full.meta_node_ref_table tn ON temp_sql_2.target_node_id = ((tn.schema_src_id::text || '||'::text) || tn.node_src_id::text)
     LEFT JOIN dg_full.meta_node_ref_table rn ON temp_sql_2.root_node_id = ((rn.schema_src_id::text || '||'::text) || rn.node_src_id::text)
  WHERE 1 = 1 AND temp_sql_2.src_node_id <> temp_sql_2.root_node_id AND temp_sql_2.target_node_id <> temp_sql_2.root_node_id
  GROUP BY temp_sql_2.src_node_id, sn.node_type_cd, sn.src_cd, temp_sql_2.target_node_id, tn.node_type_cd, tn.src_cd, temp_sql_2.root_node_id, rn.node_type_cd;


-- dg_full.vmeta_search_graph_target_report source

CREATE OR REPLACE VIEW dg_full.vmeta_search_graph_target_report
AS SELECT tt.root_node_id AS "Финальная таблица (наша витрина)",
    tt.root_node_type_cd AS "Тип объекта",
    tt.period_type_comment AS "Расписание",
    tt.period_refresh_comment AS "Триггер",
    array_remove(array_agg(
        CASE
            WHEN tt.node_type_cd::text = 'Function'::text THEN tt.node_id
            ELSE NULL::text
        END), NULL::text) AS "Запускает функцию",
        CASE
            WHEN tt.node_type_cd::text <> 'Function'::text THEN tt.node_id
            ELSE NULL::text
        END AS "Зависит от таблицы (источник)",
        CASE
            WHEN tt.node_type_cd::text <> 'Function'::text THEN tt.ctl_wf_node_id
            ELSE NULL::text
        END AS "CTL Поток источника",
    array_remove(array_agg(tt.dpt), NULL::integer) AS "Уровень вложенности"
   FROM ( SELECT DISTINCT t.root_node_id,
            t.root_node_type_cd,
            t.node_type_cd,
            t.node_id,
            t.depth AS dpt,
            n.src_node_id AS ctl_entity_node_id,
            n1.src_node_id AS ctl_wf_node_id,
            s.period_type_comment,
            s.period_refresh_comment
           FROM dg_full.meta_search_graph_target_all_obj t
             LEFT JOIN dg_full.meta_edge_link n ON t.node_id = n.target_node_id AND n.src_cd::text = 'CTL'::text
             LEFT JOIN dg_full.meta_edge_link n1 ON n.src_node_id = n1.target_node_id AND n.src_cd::text = 'CTL'::text
             LEFT JOIN dg_full.meta_scheduler_hsat s ON ((s.schema_src_id::text || '||'::text) || s.node_src_id::text) = t.root_node_id AND s.period_refresh_comment ~~ '%wf_event_sched%'::text
          WHERE 1 = 1 AND t.src_cd = 'GP'::text AND (t.root_node_type_cd::text = ANY (ARRAY['View'::character varying::text, 'Table'::character varying::text]))
          GROUP BY t.root_node_id, t.root_node_type_cd, t.node_type_cd, t.node_id, t.depth, n.src_node_id, n1.src_node_id, s.period_type_comment, s.period_refresh_comment) tt
  GROUP BY tt.root_node_id, tt.root_node_type_cd, tt.period_type_comment, tt.period_refresh_comment,
        CASE
            WHEN tt.node_type_cd::text <> 'Function'::text THEN tt.node_id
            ELSE NULL::text
        END,
        CASE
            WHEN tt.node_type_cd::text <> 'Function'::text THEN tt.ctl_wf_node_id
            ELSE NULL::text
        END;


-- dg_full.vmeta_sg_category source

CREATE OR REPLACE VIEW dg_full.vmeta_sg_category
AS WITH RECURSIVE sg_category(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parentid AS parent_id,
            g.name AS name_,
            1 AS depth,
            ARRAY[g.name] AS path,
            false AS cycle,
            g.name AS root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g
          WHERE 1 = 1 AND g.parentid = 0 AND (g.id = ANY (ARRAY[1764, 1964])) AND g.deleted = false
        UNION ALL
         SELECT g1.id,
            g1.parentid AS parent_id,
            g1.name AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name,
            g1.name = ANY (p.path),
            p.root_name_id
           FROM s_grnplm_as_cib_gm_ods_ctl.category g1
             JOIN sg_category p ON p.id = g1.parentid
          WHERE 1 = 1 AND NOT p.cycle AND g1.deleted = false
        )
 SELECT sg_category.id,
    sg_category.parent_id,
    sg_category.name_,
    sg_category.depth,
    sg_category.path,
    sg_category.cycle,
    sg_category.root_name_id::character varying(4000) AS root_name_id
   FROM sg_category;


-- dg_full.vmeta_sg_entity source

CREATE OR REPLACE VIEW dg_full.vmeta_sg_entity
AS WITH RECURSIVE sg_entity(id, parent_id, name_, depth, path, cycle) AS (
         SELECT g.id,
            g.parent_id,
            g.name_::text AS name_,
            1 AS depth,
            ARRAY[g.name_::text] AS path,
            false AS cycle,
            g.name_ AS root_name_id,
            g.path AS path_
           FROM s_grnplm_as_cib_gm_stg_espd.ctl_entity g
          WHERE 1 = 1 AND g.parent_id = 0
        UNION ALL
         SELECT g1.id,
            g1.parent_id,
            g1.name_::text AS name_,
            p.depth + 1 AS depth,
            p.path || g1.name_::text,
            g1.name_::text = ANY (p.path),
            p.root_name_id,
            g1.path AS path_
           FROM s_grnplm_as_cib_gm_stg_espd.ctl_entity g1
             JOIN sg_entity p ON p.id = g1.parent_id
          WHERE 1 = 1 AND NOT p.cycle
        )
 SELECT min(t.id) AS id,
    t.name_
   FROM sg_entity t
  WHERE 1 = 1
  GROUP BY t.name_;