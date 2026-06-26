-- dg_full.meta_add_business_kkd definition

-- Drop table

-- DROP TABLE dg_full.meta_add_business_kkd;

CREATE TABLE dg_full.meta_add_business_kkd (
	schema_src_id varchar(250) NULL, -- Схема обьекта
	table_src_id varchar(250) NULL, -- Название таблицы
	check_sql text NULL, -- SQL запрос бизнес проверки
	screen_category text NULL, -- Название проверки
	schema_node_id varchar(32) NULL,
	load_dttm varchar(16) NULL -- Дата обновления
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;

-- Column comments

COMMENT ON COLUMN dg_full.meta_add_business_kkd.schema_src_id IS 'Схема обьекта';
COMMENT ON COLUMN dg_full.meta_add_business_kkd.table_src_id IS 'Название таблицы';
COMMENT ON COLUMN dg_full.meta_add_business_kkd.check_sql IS 'SQL запрос бизнес проверки';
COMMENT ON COLUMN dg_full.meta_add_business_kkd.screen_category IS 'Название проверки';
COMMENT ON COLUMN dg_full.meta_add_business_kkd.load_dttm IS 'Дата обновления';


-- dg_full.meta_batch_fact definition

-- Drop table

-- DROP TABLE dg_full.meta_batch_fact;

CREATE TABLE dg_full.meta_batch_fact (
	batch_id int4 NOT NULL, -- ID пакета
	start_dt timestamp NULL, -- Дата начала пакета проверок
	end_dt timestamp NULL, -- Дата окончания пакета проверок
	stts text NULL, -- Общий статус по пакету
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	batch_params text NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (batch_id);
COMMENT ON TABLE dg_full.meta_batch_fact IS 'Пакетное измерение содержит запись для каждого вызова общего
пакетного процесса — и обычно содержит интересные временные метки и кол-во
записей обработанных';

-- Column comments

COMMENT ON COLUMN dg_full.meta_batch_fact.batch_id IS 'ID пакета';
COMMENT ON COLUMN dg_full.meta_batch_fact.start_dt IS 'Дата начала пакета проверок';
COMMENT ON COLUMN dg_full.meta_batch_fact.end_dt IS 'Дата окончания пакета проверок';
COMMENT ON COLUMN dg_full.meta_batch_fact.stts IS 'Общий статус по пакету';
COMMENT ON COLUMN dg_full.meta_batch_fact.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_batch_fact.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_batch_fact.src_cd IS 'Код системы-источника';


-- dg_full.meta_dq_rrm_gold definition

-- Drop table

-- DROP TABLE dg_full.meta_dq_rrm_gold;

CREATE TABLE dg_full.meta_dq_rrm_gold (
	schema_name name NULL,
	user_name name NULL,
	access_type text NULL,
	privilege_type text NULL,
	inheritance_chain_details text NULL,
	inheritance_depth int4 NULL,
	wf_load_id int8 NULL,
	hash_diff text NULL,
	eff_from_dttm timestamp NULL,
	eff_to_dttm timestamp NULL,
	wf_load_dttm timestamp NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (schema_name);


-- dg_full.meta_edge_link definition

-- Drop table

-- DROP TABLE dg_full.meta_edge_link;

CREATE TABLE dg_full.meta_edge_link (
	edge_id int4 NULL, -- ID связки
	load_dttm timestamp(0) NULL, -- Дата загрузки
	src_cd varchar(20) NULL, -- Источник
	wf_load_id numeric(22) NULL, -- ID потока
	eff_from_dttm timestamp NULL, -- Дата с
	eff_to_dttm timestamp NULL, -- Дата по
	last_seen_dttm timestamp(0) NULL, -- Дата загрузки
	src_node_src_id varchar(250) NULL, -- Источник - объект
	src_schema_src_id varchar(250) NULL, -- Источник - схема
	target_node_src_id varchar(250) NULL, -- Приемник - объект
	target_schema_src_id varchar(250) NULL, -- Приемник - схема
	edge_type_src_id int4 NULL, -- Тип связки
	property_id int4 NULL,
	weight numeric(15, 2) NULL, -- Вес
	order_by int4 NULL, -- Порядок
	is_active bool NULL, -- Признак "активный"
	edge_type_cd varchar(100) NULL,
	src_node_id text NULL,
	target_node_id text NULL,
	tgt_node_type_cd text NULL,
	src_node_type_cd text NULL,
	enable_dq text NULL,
	column_key_list text NULL -- Список ключевых полей
)
WITH (
	autovacuum_analyze_scale_factor=0.05
)
DISTRIBUTED BY (src_schema_src_id, src_node_src_id, target_schema_src_id, target_node_src_id);

-- Column comments

COMMENT ON COLUMN dg_full.meta_edge_link.edge_id IS 'ID связки';
COMMENT ON COLUMN dg_full.meta_edge_link.load_dttm IS 'Дата загрузки';
COMMENT ON COLUMN dg_full.meta_edge_link.src_cd IS 'Источник';
COMMENT ON COLUMN dg_full.meta_edge_link.wf_load_id IS 'ID потока';
COMMENT ON COLUMN dg_full.meta_edge_link.eff_from_dttm IS 'Дата с';
COMMENT ON COLUMN dg_full.meta_edge_link.eff_to_dttm IS 'Дата по';
COMMENT ON COLUMN dg_full.meta_edge_link.last_seen_dttm IS 'Дата загрузки';
COMMENT ON COLUMN dg_full.meta_edge_link.src_node_src_id IS 'Источник - объект';
COMMENT ON COLUMN dg_full.meta_edge_link.src_schema_src_id IS 'Источник - схема';
COMMENT ON COLUMN dg_full.meta_edge_link.target_node_src_id IS 'Приемник - объект';
COMMENT ON COLUMN dg_full.meta_edge_link.target_schema_src_id IS 'Приемник - схема';
COMMENT ON COLUMN dg_full.meta_edge_link.edge_type_src_id IS 'Тип связки';
COMMENT ON COLUMN dg_full.meta_edge_link.weight IS 'Вес';
COMMENT ON COLUMN dg_full.meta_edge_link.order_by IS 'Порядок';
COMMENT ON COLUMN dg_full.meta_edge_link.is_active IS 'Признак "активный"';
COMMENT ON COLUMN dg_full.meta_edge_link.column_key_list IS 'Список ключевых полей';


-- dg_full.meta_edge_link_old definition

-- Drop table

-- DROP TABLE dg_full.meta_edge_link_old;

CREATE TABLE dg_full.meta_edge_link_old (
	edge_id int4 NULL,
	load_dttm timestamp(0) NULL,
	src_cd varchar(20) NULL,
	wf_load_id numeric(22) NULL,
	eff_from_dttm timestamp NULL,
	eff_to_dttm timestamp NULL,
	last_seen_dttm timestamp(0) NULL,
	src_node_src_id varchar(250) NULL,
	src_schema_src_id varchar(250) NULL,
	target_node_src_id varchar(250) NULL,
	target_schema_src_id varchar(250) NULL,
	edge_type_src_id int4 NULL,
	property_id int4 NULL,
	weight numeric(15, 2) NULL,
	order_by int4 NULL,
	is_active bool NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_edge_link_test definition

-- Drop table

-- DROP TABLE dg_full.meta_edge_link_test;

CREATE TABLE dg_full.meta_edge_link_test (
	edge_id int4 NULL,
	load_dttm timestamp(0) NULL,
	src_cd varchar(20) NULL,
	wf_load_id numeric(22) NULL,
	eff_from_dttm timestamp NULL,
	eff_to_dttm timestamp NULL,
	last_seen_dttm timestamp(0) NULL,
	src_node_src_id varchar(250) NULL,
	src_schema_src_id varchar(250) NULL,
	target_node_src_id varchar(250) NULL,
	target_schema_src_id varchar(250) NULL,
	edge_type_src_id int4 NULL,
	property_id int4 NULL,
	weight numeric(15, 2) NULL,
	order_by int4 NULL,
	is_active bool NULL
)
WITH (
	appendonly=true,
	compresstype=zstd
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_edge_type_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_edge_type_ref_table;

CREATE TABLE dg_full.meta_edge_type_ref_table (
	edge_type_src_id int4 NOT NULL, -- Id роли
	edge_type_cd varchar(100) NULL, -- Код роли
	descr varchar(250) NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (edge_type_src_id);
COMMENT ON TABLE dg_full.meta_edge_type_ref_table IS 'Роли ребер';

-- Column comments

COMMENT ON COLUMN dg_full.meta_edge_type_ref_table.edge_type_src_id IS 'Id роли';
COMMENT ON COLUMN dg_full.meta_edge_type_ref_table.edge_type_cd IS 'Код роли';
COMMENT ON COLUMN dg_full.meta_edge_type_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_edge_type_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_edge_type_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_edge_type_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_email_recipient_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_email_recipient_ref_table;

CREATE TABLE dg_full.meta_email_recipient_ref_table (
	email_recipient_id int4 NOT NULL, -- Id получателя
	email_recipient_cd text NULL, -- Код получателя
	descr text NULL, -- Описание
	"type" varchar(250) NULL, -- Тип получателя
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (email_recipient_id);
COMMENT ON TABLE dg_full.meta_email_recipient_ref_table IS 'Получатели рассылок';

-- Column comments

COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table.email_recipient_id IS 'Id получателя';
COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table.email_recipient_cd IS 'Код получателя';
COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table."type" IS 'Тип получателя';
COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_email_recipient_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_email_template_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_email_template_ref_table;

CREATE TABLE dg_full.meta_email_template_ref_table (
	email_template_id int4 NOT NULL, -- Id шаблона письма
	email_template_title text NULL, -- Заголовок письма
	email_template_body text NULL, -- Текст письма
	"type" varchar(250) NULL, -- Тип письма
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (email_template_id);
COMMENT ON TABLE dg_full.meta_email_template_ref_table IS 'Шаблоны писем с форматированием и алиасами для замены';

-- Column comments

COMMENT ON COLUMN dg_full.meta_email_template_ref_table.email_template_id IS 'Id шаблона письма';
COMMENT ON COLUMN dg_full.meta_email_template_ref_table.email_template_title IS 'Заголовок письма';
COMMENT ON COLUMN dg_full.meta_email_template_ref_table.email_template_body IS 'Текст письма';
COMMENT ON COLUMN dg_full.meta_email_template_ref_table."type" IS 'Тип письма';
COMMENT ON COLUMN dg_full.meta_email_template_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_email_template_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_email_template_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_error_event_fact definition

-- Drop table

-- DROP TABLE dg_full.meta_error_event_fact;

CREATE TABLE dg_full.meta_error_event_fact (
	batch_id int4 NOT NULL, -- ID Пакета
	schema_src_id varchar(250) NOT NULL, -- ID системы-источника\схемы
	table_src_id varchar(250) NOT NULL, -- ID объекта с источника
	screen_id int4 NOT NULL, -- Шаблон
	event_time int4 NULL, -- Кол-во секунд от полуночи
	record_identifier json NULL, -- Универсальный идентификатор строки
	final_severity_score float8 NULL, -- Окончательная оценка серъезности ошибки
	record_error float8 NULL, -- Кол-во строк не прошедших проверку
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	check_sql text NULL, -- Скрипт реализованной проверки
	wf_id int8 NULL, -- Идентификатор потока
	metric text NULL, -- Категория проверки
	key_metric text NULL, -- Группа категория проверки
	value text NULL, -- Результат проверки
	exception_action_id int4 NULL -- ID Действие при ошибке
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (batch_id);
COMMENT ON TABLE dg_full.meta_error_event_fact IS 'Список рассылок ';

-- Column comments

COMMENT ON COLUMN dg_full.meta_error_event_fact.batch_id IS 'ID Пакета';
COMMENT ON COLUMN dg_full.meta_error_event_fact.schema_src_id IS 'ID системы-источника\схемы';
COMMENT ON COLUMN dg_full.meta_error_event_fact.table_src_id IS 'ID объекта с источника';
COMMENT ON COLUMN dg_full.meta_error_event_fact.screen_id IS 'Шаблон';
COMMENT ON COLUMN dg_full.meta_error_event_fact.event_time IS 'Кол-во секунд от полуночи';
COMMENT ON COLUMN dg_full.meta_error_event_fact.record_identifier IS 'Универсальный идентификатор строки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.final_severity_score IS 'Окончательная оценка серъезности ошибки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.record_error IS 'Кол-во строк не прошедших проверку';
COMMENT ON COLUMN dg_full.meta_error_event_fact.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_error_event_fact.check_sql IS 'Скрипт реализованной проверки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.wf_id IS 'Идентификатор потока';
COMMENT ON COLUMN dg_full.meta_error_event_fact.metric IS 'Категория проверки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.key_metric IS 'Группа категория проверки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.value IS 'Результат проверки';
COMMENT ON COLUMN dg_full.meta_error_event_fact.exception_action_id IS 'ID Действие при ошибке';


-- dg_full.meta_error_event_stat definition

-- Drop table

-- DROP TABLE dg_full.meta_error_event_stat;

CREATE TABLE dg_full.meta_error_event_stat (
	schema_src_id varchar(250) NULL,
	table_src_id varchar(250) NULL,
	screen_id int4 NULL,
	metric text NULL,
	avg_rec_error float8 NULL,
	stddev_rec_error float8 NULL,
	str_cnt int8 NULL,
	min_rec_error float8 NULL,
	max_rec_error float8 NULL,
	load_dttm timestamp NULL,
	unit text NULL,
	avg_moving_rec_error float8 NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (screen_id, schema_src_id, table_src_id);


-- dg_full.meta_event_hsat definition

-- Drop table

-- DROP TABLE dg_full.meta_event_hsat;

CREATE TABLE dg_full.meta_event_hsat (
	event_id int4 NOT NULL, -- ID загрузки
	node_src_id varchar(250) NULL, -- ID объекта с источника
	schema_src_id varchar(250) NULL, -- Id схемы
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	eff_from_dttm timestamp(0) NULL, -- Дата и время начала действия записи
	eff_to_dttm timestamp(0) NULL, -- Дата и время окончания действия записи
	last_seen_dttm timestamp(0) NULL, -- Дата и время обновления
	start_dt date NULL, -- Дата\время запуска потока
	end_dt date NULL, -- Дата\время окончания
	stts_id int4 NULL, -- Статус потока
	error_descr text NULL -- Ошибка
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (event_id);
COMMENT ON TABLE dg_full.meta_event_hsat IS 'Запуски потоков загрузки \ функций';

-- Column comments

COMMENT ON COLUMN dg_full.meta_event_hsat.event_id IS 'ID загрузки';
COMMENT ON COLUMN dg_full.meta_event_hsat.node_src_id IS 'ID объекта с источника';
COMMENT ON COLUMN dg_full.meta_event_hsat.schema_src_id IS 'Id схемы';
COMMENT ON COLUMN dg_full.meta_event_hsat.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_event_hsat.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_event_hsat.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_event_hsat.eff_from_dttm IS 'Дата и время начала действия записи';
COMMENT ON COLUMN dg_full.meta_event_hsat.eff_to_dttm IS 'Дата и время окончания действия записи';
COMMENT ON COLUMN dg_full.meta_event_hsat.last_seen_dttm IS 'Дата и время обновления';
COMMENT ON COLUMN dg_full.meta_event_hsat.start_dt IS 'Дата\время запуска потока';
COMMENT ON COLUMN dg_full.meta_event_hsat.end_dt IS 'Дата\время окончания';
COMMENT ON COLUMN dg_full.meta_event_hsat.stts_id IS 'Статус потока';
COMMENT ON COLUMN dg_full.meta_event_hsat.error_descr IS 'Ошибка';


-- dg_full.meta_event_statistic_hsat definition

-- Drop table

-- DROP TABLE dg_full.meta_event_statistic_hsat;

CREATE TABLE dg_full.meta_event_statistic_hsat (
	event_statistic_id int4 NOT NULL, -- ID статистики загрузки
	event_id int4 NOT NULL, -- ID загрузки
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	eff_from_dttm timestamp(0) NULL, -- Дата и время начала действия записи
	eff_to_dttm timestamp(0) NULL, -- Дата и время окончания действия записи
	last_seen_dttm timestamp(0) NULL, -- Дата и время обновления
	statistic_src_id int4 NOT NULL, -- Id статистики
	statistic_val text NULL -- Значение статистики
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (event_statistic_id);
COMMENT ON TABLE dg_full.meta_event_statistic_hsat IS 'Статистики по потокам';

-- Column comments

COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.event_statistic_id IS 'ID статистики загрузки';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.event_id IS 'ID загрузки';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.eff_from_dttm IS 'Дата и время начала действия записи';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.eff_to_dttm IS 'Дата и время окончания действия записи';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.last_seen_dttm IS 'Дата и время обновления';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.statistic_src_id IS 'Id статистики';
COMMENT ON COLUMN dg_full.meta_event_statistic_hsat.statistic_val IS 'Значение статистики';


-- dg_full.meta_exception_action_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_exception_action_ref_table;

CREATE TABLE dg_full.meta_exception_action_ref_table (
	exception_action_id int4 NOT NULL, -- ID Действие при ошибке
	exception_action_name text NULL, -- Действие при ошибке
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	exception_action_descr text NULL,
	exception_group_id int4 NULL,
	prc_from float4 NULL,
	prc_to float4 NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (exception_action_id);
COMMENT ON TABLE dg_full.meta_exception_action_ref_table IS 'Действие при ошибке - пропустить строку, отложить строку в карантин, остановить весь процесс ETL до разбора ошибки 
1. Pass the record with no errors
2. Pass the record, ?agging offending column values
3. Reject the record
4. Stop the ETL job stream';

-- Column comments

COMMENT ON COLUMN dg_full.meta_exception_action_ref_table.exception_action_id IS 'ID Действие при ошибке';
COMMENT ON COLUMN dg_full.meta_exception_action_ref_table.exception_action_name IS 'Действие при ошибке';
COMMENT ON COLUMN dg_full.meta_exception_action_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_exception_action_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_exception_action_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_exception_group_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_exception_group_ref_table;

CREATE TABLE dg_full.meta_exception_group_ref_table (
	exception_group_id int4 NOT NULL, -- ID Группа интервалов
	exception_group_name text NULL, -- Группа интервалов
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	exception_group_descr text NULL -- Описание
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (exception_group_id);
COMMENT ON TABLE dg_full.meta_exception_group_ref_table IS 'Группа интервалов для определения рассчитанного порога';

-- Column comments

COMMENT ON COLUMN dg_full.meta_exception_group_ref_table.exception_group_id IS 'ID Группа интервалов';
COMMENT ON COLUMN dg_full.meta_exception_group_ref_table.exception_group_name IS 'Группа интервалов';
COMMENT ON COLUMN dg_full.meta_exception_group_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_exception_group_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_exception_group_ref_table.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_exception_group_ref_table.exception_group_descr IS 'Описание';


-- dg_full.meta_is_active_objects definition

-- Drop table

-- DROP TABLE dg_full.meta_is_active_objects;

CREATE TABLE dg_full.meta_is_active_objects (
	routine_schema varchar NULL,
	routine_name varchar NULL,
	data_type varchar NULL,
	routine_type varchar NULL,
	load_dttm timestamptz NULL,
	is_active int4 NULL
)
DISTRIBUTED BY (routine_name);


-- dg_full.meta_ld_dq_statistic_lg definition

-- Drop table

-- DROP TABLE dg_full.meta_ld_dq_statistic_lg;

CREATE TABLE dg_full.meta_ld_dq_statistic_lg (
	schema_src_id text NULL,
	schema_src_descr text NULL,
	all_cn int8 NULL,
	tmpl_cn int8 NULL,
	fact_cn int8 NULL,
	start_dt date NULL,
	screen_template_id int4 NULL,
	screen_category text NULL,
	tmpl_ttl_cn int8 NULL,
	fact_ttl_cn int8 NULL,
	tmpl_ttl_da_cn int8 NULL,
	fact_ttl_da_cn int8 NULL,
	plan_ttl_cn int8 NULL,
	fact_wf_ttl_cn int8 NULL,
	plan_kkd_ttl_cn int8 NULL,
	fact_kkd_ttl_cn int8 NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (schema_src_id);


-- dg_full.meta_ldtoprom_mapping definition

-- Drop table

-- DROP TABLE dg_full.meta_ldtoprom_mapping;

CREATE TABLE dg_full.meta_ldtoprom_mapping (
	ld text NULL,
	prom text NULL,
	table_src_id text NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (ld);


-- dg_full.meta_log_event_hsat definition

-- Drop table

-- DROP TABLE dg_full.meta_log_event_hsat;

CREATE TABLE dg_full.meta_log_event_hsat (
	log_event_id int4 NOT NULL, -- ID события
	node_src_id varchar(250) NULL, -- ID объекта с источника
	schema_src_id varchar(250) NULL, -- Id схемы
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	eff_from_dttm timestamp(0) NULL, -- Дата и время начала действия записи
	eff_to_dttm timestamp(0) NULL, -- Дата и время окончания действия записи
	last_seen_dttm timestamp(0) NULL, -- Дата и время обновления
	log_event_dt date NULL,
	stts_id int4 NULL,
	error_descr text NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (log_event_id);
COMMENT ON TABLE dg_full.meta_log_event_hsat IS 'События по логам';

-- Column comments

COMMENT ON COLUMN dg_full.meta_log_event_hsat.log_event_id IS 'ID события';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.node_src_id IS 'ID объекта с источника';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.schema_src_id IS 'Id схемы';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.eff_from_dttm IS 'Дата и время начала действия записи';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.eff_to_dttm IS 'Дата и время окончания действия записи';
COMMENT ON COLUMN dg_full.meta_log_event_hsat.last_seen_dttm IS 'Дата и время обновления';


-- dg_full.meta_node_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_node_ref_table;

CREATE TABLE dg_full.meta_node_ref_table (
	node_src_id varchar(250) NULL, -- Вершина - Объект
	schema_src_id varchar(250) NULL, -- Вершина - Схема
	load_dttm timestamp(0) NULL, -- Дата загрузки
	src_cd varchar(20) NULL, -- Источник
	wf_load_id numeric(22) NULL, -- ID потока
	eff_from_dttm timestamp(0) NULL, -- Дата с
	eff_to_dttm timestamp(0) NULL, -- Дата по
	last_seen_dttm timestamp(0) NULL, -- Дата загрузки
	node_cd varchar(250) NULL, -- Код вершины
	node_name text NULL, -- Наименование вершины
	node_type_src_id int4 NULL, -- Тип вершины
	is_active bool NULL, -- Признак "активный"
	created_dt date NULL, -- Дата создания
	modified_dt date NULL, -- Дата модификации
	node_type_cd varchar(20) NULL,
	is_owner int4 NULL
)
WITH (
	autovacuum_analyze_scale_factor=0.05
)
DISTRIBUTED BY (schema_src_id, node_src_id);

-- Column comments

COMMENT ON COLUMN dg_full.meta_node_ref_table.node_src_id IS 'Вершина - Объект';
COMMENT ON COLUMN dg_full.meta_node_ref_table.schema_src_id IS 'Вершина - Схема';
COMMENT ON COLUMN dg_full.meta_node_ref_table.load_dttm IS 'Дата загрузки';
COMMENT ON COLUMN dg_full.meta_node_ref_table.src_cd IS 'Источник';
COMMENT ON COLUMN dg_full.meta_node_ref_table.wf_load_id IS 'ID потока';
COMMENT ON COLUMN dg_full.meta_node_ref_table.eff_from_dttm IS 'Дата с';
COMMENT ON COLUMN dg_full.meta_node_ref_table.eff_to_dttm IS 'Дата по';
COMMENT ON COLUMN dg_full.meta_node_ref_table.last_seen_dttm IS 'Дата загрузки';
COMMENT ON COLUMN dg_full.meta_node_ref_table.node_cd IS 'Код вершины';
COMMENT ON COLUMN dg_full.meta_node_ref_table.node_name IS 'Наименование вершины';
COMMENT ON COLUMN dg_full.meta_node_ref_table.node_type_src_id IS 'Тип вершины';
COMMENT ON COLUMN dg_full.meta_node_ref_table.is_active IS 'Признак "активный"';
COMMENT ON COLUMN dg_full.meta_node_ref_table.created_dt IS 'Дата создания';
COMMENT ON COLUMN dg_full.meta_node_ref_table.modified_dt IS 'Дата модификации';


-- dg_full.meta_node_ref_table_test definition

-- Drop table

-- DROP TABLE dg_full.meta_node_ref_table_test;

CREATE TABLE dg_full.meta_node_ref_table_test (
	node_src_id varchar(250) NULL,
	schema_src_id varchar(250) NULL,
	load_dttm timestamp(0) NULL,
	src_cd varchar(20) NULL,
	wf_load_id numeric(22) NULL,
	eff_from_dttm timestamp(0) NULL,
	eff_to_dttm timestamp(0) NULL,
	last_seen_dttm timestamp(0) NULL,
	node_cd varchar(250) NULL,
	node_name varchar(250) NULL,
	node_type_src_id int4 NULL,
	is_active bool NULL,
	created_dt date NULL,
	modified_dt date NULL
)
WITH (
	appendonly=true,
	compresstype=zstd
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_node_type_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_node_type_ref_table;

CREATE TABLE dg_full.meta_node_type_ref_table (
	node_type_src_id int4 NOT NULL, -- Id типа объекта
	node_type_cd varchar(20) NULL, -- Код типа объекта
	descr varchar(250) NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (node_type_src_id);
COMMENT ON TABLE dg_full.meta_node_type_ref_table IS 'Типы объектов - таблицы, представления, функции, потоки, qvd-файлы, приложения qs ';

-- Column comments

COMMENT ON COLUMN dg_full.meta_node_type_ref_table.node_type_src_id IS 'Id типа объекта';
COMMENT ON COLUMN dg_full.meta_node_type_ref_table.node_type_cd IS 'Код типа объекта';
COMMENT ON COLUMN dg_full.meta_node_type_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_node_type_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_node_type_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_node_type_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_object_group_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_object_group_ref_table;

CREATE TABLE dg_full.meta_object_group_ref_table (
	object_group_id int8 NOT NULL, -- ID группы объекта - проверяются в одном запросе
	object_group_name text NOT NULL, -- Наименование
	object_group_descr text NULL, -- Описание группы
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	is_active int4 NULL,
	object_group_type int4 NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (object_group_id);
COMMENT ON TABLE dg_full.meta_object_group_ref_table IS 'Группа объектов. Если указана, то объекты обрабатываются в одном запросе';

-- Column comments

COMMENT ON COLUMN dg_full.meta_object_group_ref_table.object_group_id IS 'ID группы объекта - проверяются в одном запросе';
COMMENT ON COLUMN dg_full.meta_object_group_ref_table.object_group_name IS 'Наименование';
COMMENT ON COLUMN dg_full.meta_object_group_ref_table.object_group_descr IS 'Описание группы';
COMMENT ON COLUMN dg_full.meta_object_group_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_object_group_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_object_group_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_object_group_ref_table_manual definition

-- Drop table

-- DROP TABLE dg_full.meta_object_group_ref_table_manual;

CREATE TABLE dg_full.meta_object_group_ref_table_manual (
	object_group_id int8 NULL,
	object_group_name text NULL,
	object_group_descr text NULL,
	load_dttm timestamp(0) NULL,
	wf_load_id numeric(22) NULL,
	src_cd varchar(20) NULL,
	is_active int4 NULL,
	object_group_type int4 NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_object_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_object_ref_table;

CREATE TABLE dg_full.meta_object_ref_table (
	object_id int8 NOT NULL, -- ID объекта
	schema_src_id varchar(250) NOT NULL, -- ID системы-источника\схемы
	table_src_id varchar(250) NOT NULL, -- ID объекта с источника
	attribute_src_id text NULL, -- ID атрибута
	attribute_type varchar(100) NULL, -- Тип атрибута для применения спец. проверок
	object_order int4 NULL, -- Последовательность объектов
	is_active int4 NULL, -- Признак необходимости проверки
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	node_type_src_id int4 NULL, -- ID типа объекта
	object_group_id int8 NULL, -- ID группы объектов
	object_alias text NULL -- Алиас объекта в шаблоне запроса
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (object_id);
COMMENT ON TABLE dg_full.meta_object_ref_table IS 'Объекты, к которым применяются правила проверки.
Объект может быть целиком таблица (тогда поле Attribute Key не заполнено), может быть атрибут.
Объекты можно представить в виде вью из системных таблиц GP';

-- Column comments

COMMENT ON COLUMN dg_full.meta_object_ref_table.object_id IS 'ID объекта';
COMMENT ON COLUMN dg_full.meta_object_ref_table.schema_src_id IS 'ID системы-источника\схемы';
COMMENT ON COLUMN dg_full.meta_object_ref_table.table_src_id IS 'ID объекта с источника';
COMMENT ON COLUMN dg_full.meta_object_ref_table.attribute_src_id IS 'ID атрибута';
COMMENT ON COLUMN dg_full.meta_object_ref_table.attribute_type IS 'Тип атрибута для применения спец. проверок';
COMMENT ON COLUMN dg_full.meta_object_ref_table.object_order IS 'Последовательность объектов';
COMMENT ON COLUMN dg_full.meta_object_ref_table.is_active IS 'Признак необходимости проверки';
COMMENT ON COLUMN dg_full.meta_object_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_object_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_object_ref_table.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_object_ref_table.node_type_src_id IS 'ID типа объекта';
COMMENT ON COLUMN dg_full.meta_object_ref_table.object_group_id IS 'ID группы объектов';
COMMENT ON COLUMN dg_full.meta_object_ref_table.object_alias IS 'Алиас объекта в шаблоне запроса';


-- dg_full.meta_object_ref_table_manual definition

-- Drop table

-- DROP TABLE dg_full.meta_object_ref_table_manual;

CREATE TABLE dg_full.meta_object_ref_table_manual (
	object_id int8 NULL,
	schema_src_id varchar(250) NULL,
	table_src_id varchar(250) NULL,
	attribute_src_id text NULL,
	attribute_type varchar(100) NULL,
	object_order int4 NULL,
	is_active int4 NULL,
	load_dttm timestamp(0) NULL,
	wf_load_id numeric(22) NULL,
	src_cd varchar(20) NULL,
	node_type_src_id int4 NULL,
	object_group_id int8 NULL,
	object_alias text NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_ods_lineage definition

-- Drop table

-- DROP TABLE dg_full.meta_ods_lineage;

CREATE TABLE dg_full.meta_ods_lineage (
	app_key text NULL,
	lng_object text NULL,
	lng_src_flag text NULL,
	lng_flow text NULL,
	lng_object_type text NULL,
	lng_application text NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_period_type_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_period_type_ref_table;

CREATE TABLE dg_full.meta_period_type_ref_table (
	period_type_id bpchar(10) NOT NULL, -- ID периодичности
	descr varchar(250) NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (period_type_id);
COMMENT ON TABLE dg_full.meta_period_type_ref_table IS 'Тип периодичности запуска: каждый день\неделя\месяц';

-- Column comments

COMMENT ON COLUMN dg_full.meta_period_type_ref_table.period_type_id IS 'ID периодичности';
COMMENT ON COLUMN dg_full.meta_period_type_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_period_type_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_period_type_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_period_type_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_priority_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_priority_ref_table;

CREATE TABLE dg_full.meta_priority_ref_table (
	priority_src_id int4 NOT NULL, -- Id приоритета
	priority_cd text NOT NULL, -- Код приоритета
	priority_nm text NULL, -- Наим. приоритета
	descr text NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (priority_cd);
COMMENT ON TABLE dg_full.meta_priority_ref_table IS 'Список приоритетов';

-- Column comments

COMMENT ON COLUMN dg_full.meta_priority_ref_table.priority_src_id IS 'Id приоритета';
COMMENT ON COLUMN dg_full.meta_priority_ref_table.priority_cd IS 'Код приоритета';
COMMENT ON COLUMN dg_full.meta_priority_ref_table.priority_nm IS 'Наим. приоритета';
COMMENT ON COLUMN dg_full.meta_priority_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_priority_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_priority_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_priority_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_property_hsat definition

-- Drop table

-- DROP TABLE dg_full.meta_property_hsat;

CREATE TABLE dg_full.meta_property_hsat (
	property_id int4 NULL,
	object_src_id varchar(250) NULL,
	schema_src_id varchar(250) NULL,
	edge_id int4 NULL,
	load_dttm timestamp(0) NULL,
	src_cd varchar(20) NULL,
	wf_load_id numeric(22) NULL,
	eff_from_dttm timestamp(0) NULL,
	eff_to_dttm timestamp(0) NULL,
	last_seen_dttm timestamp(0) NULL,
	property_type_src_id int4 NULL,
	property_val text NULL
)
DISTRIBUTED BY (property_id);


-- dg_full.meta_property_type_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_property_type_ref_table;

CREATE TABLE dg_full.meta_property_type_ref_table (
	property_type_src_id int4 NOT NULL, -- Id типа свойства
	descr varchar(250) NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (property_type_src_id);
COMMENT ON TABLE dg_full.meta_property_type_ref_table IS 'Тип свойства вершины \ ребра';

-- Column comments

COMMENT ON COLUMN dg_full.meta_property_type_ref_table.property_type_src_id IS 'Id типа свойства';
COMMENT ON COLUMN dg_full.meta_property_type_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_property_type_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_property_type_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_property_type_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_run_signal definition

-- Drop table

-- DROP TABLE dg_full.meta_run_signal;

CREATE TABLE dg_full.meta_run_signal (
	batch_id int4 NOT NULL,
	schema_src_id varchar(250) NOT NULL,
	table_src_id varchar(250) NOT NULL,
	screen_id int4 NOT NULL,
	email_template_title text NOT NULL,
	processed_template text NOT NULL,
	"type" text NOT NULL,
	email_recipient_cd text NOT NULL,
	load_dttm timestamp(0) NULL,
	wf_load_id numeric(22) NULL,
	wf_id int8 NULL,
	proccesed_attached text NULL -- Результаты проверок в формате json для приложения к информационному письму
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (batch_id);

-- Column comments

COMMENT ON COLUMN dg_full.meta_run_signal.proccesed_attached IS 'Результаты проверок в формате json для приложения к информационному письму';


-- dg_full.meta_s2t_meta_graph definition

-- Drop table

-- DROP TABLE dg_full.meta_s2t_meta_graph;

CREATE TABLE dg_full.meta_s2t_meta_graph (
	"T-trg-platform" text NULL,
	"T-trg-instance" text NULL,
	"T-trg-schema" text NULL,
	"T-trg" text NULL,
	"UserName" text NULL,
	"T-trg-f" text NULL,
	target_data_relevance text NULL,
	target_data_hist text NULL,
	target_data_freq text NULL,
	"T-src-platform" text NULL,
	"T-src-instance" text NULL,
	"T-src-schema" text NULL,
	"T-src" text NULL,
	"T-src-main" text NULL,
	"T-src-f-name" text NULL,
	"T-src-f" text NULL,
	"T-src-join" text NULL,
	"T-src-join-on" text NULL,
	"T-src-where" text NULL,
	"T-src-group" text NULL,
	"T-k" text NULL,
	"T-hist-type" text NULL,
	"T-hist-role" text NULL,
	"codeDatamart" text NULL,
	"Datamart.description_source" text NULL,
	"Table.description_source" text NULL,
	root_node_id text NULL
)
DISTRIBUTED BY ("T-src");


-- dg_full.meta_scheduler_hsat definition

-- Drop table

-- DROP TABLE dg_full.meta_scheduler_hsat;

CREATE TABLE dg_full.meta_scheduler_hsat (
	scheduler_id bpchar(10) NULL, -- ID расписания загрузки
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	src_cd varchar(20) NULL, -- Код системы источника
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	eff_from_dttm timestamp NULL, -- Дата и время начала действия записи
	eff_to_dttm timestamp NULL, -- Дата и время ококнчания действия записи
	last_seen_dttm timestamp(0) NULL, -- Дата и время обновления
	node_src_id varchar(250) NULL, -- ID объекта с источника
	schema_src_id varchar(250) NULL, -- ID схемы
	scheduler_type_src_id varchar(250) NULL, -- ID значения справочника
	dt_from int4 NULL, -- На какой день начинать загрузку
	dt_to int4 NULL, -- Крайний день, когда загрузка должна быть
	time_from int4 NULL, -- Час когда начинать загрузку
	time_to int4 NULL, -- Крайний час, когда загрузка должна быть
	period_type_id int4 NULL, -- Периодичность загрузки
	every_times int4 NULL, -- Количество повторений запуска
	source_object text NULL, -- Объект-источник
	run_function_src_id text NULL, -- Запускаемая функция для заполнения витрины
	node_type_src_id int4 NULL, -- Тип объекта-источника
	period_type_comment text NULL, -- Описание периодичности загрузки
	period_refresh_comment text NULL, -- Описание режима обновления данных
	user_refresh text NULL, -- Ответственный за объект
	ods_ready text NULL, -- Ожидаемое время готовности загрузки в ods (TEXT)
	dm_ready text NULL, -- Ожидаемое время готовности загрузки в dm (TEXT)
	ods_ready_dt date NULL, -- Ожидаемая дата готовности загрузки в ods (DATE)
	dm_ready_dt date NULL, -- Ожидаемая дата готовности загрузки в dm (DATE)
	ods_ready_tm time NULL, -- Ожидаемое время готовности загрузки в ods (TIME)
	dm_ready_tm time NULL, -- Ожидаемое время готовности загрузки в dm (TIME)
	ods_start text NULL, -- Время старта потока CTL (TEXT)
	ods_start_tm time NULL, -- Время старта потока CTL (TIME)
	is_wf_time_sched_active bool NULL
)
DISTRIBUTED BY (schema_src_id, node_src_id);

-- Column comments

COMMENT ON COLUMN dg_full.meta_scheduler_hsat.scheduler_id IS 'ID расписания загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.src_cd IS 'Код системы источника';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.eff_from_dttm IS 'Дата и время начала действия записи';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.eff_to_dttm IS 'Дата и время ококнчания действия записи';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.last_seen_dttm IS 'Дата и время обновления';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.node_src_id IS 'ID объекта с источника';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.schema_src_id IS 'ID схемы';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.scheduler_type_src_id IS 'ID значения справочника';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.dt_from IS 'На какой день начинать загрузку';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.dt_to IS 'Крайний день, когда загрузка должна быть';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.time_from IS 'Час когда начинать загрузку';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.time_to IS 'Крайний час, когда загрузка должна быть';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.period_type_id IS 'Периодичность загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.every_times IS 'Количество повторений запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.source_object IS 'Объект-источник';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.run_function_src_id IS 'Запускаемая функция для заполнения витрины';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.node_type_src_id IS 'Тип объекта-источника';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.period_type_comment IS 'Описание периодичности загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.period_refresh_comment IS 'Описание режима обновления данных';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.user_refresh IS 'Ответственный за объект';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.ods_ready IS 'Ожидаемое время готовности загрузки в ods (TEXT)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.dm_ready IS 'Ожидаемое время готовности загрузки в dm (TEXT)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.ods_ready_dt IS 'Ожидаемая дата готовности загрузки в ods (DATE)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.dm_ready_dt IS 'Ожидаемая дата готовности загрузки в dm (DATE)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.ods_ready_tm IS 'Ожидаемое время готовности загрузки в ods (TIME)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.dm_ready_tm IS 'Ожидаемое время готовности загрузки в dm (TIME)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.ods_start IS 'Время старта потока CTL (TEXT)';
COMMENT ON COLUMN dg_full.meta_scheduler_hsat.ods_start_tm IS 'Время старта потока CTL (TIME)';


-- dg_full.meta_scheduler_plan definition

-- Drop table

-- DROP TABLE dg_full.meta_scheduler_plan;

CREATE TABLE dg_full.meta_scheduler_plan (
	schema_src_id text NULL, -- Вершина - Схема
	node_src_id text NULL, -- Вершина - Объект
	scheduler_type_src_id varchar(250) NULL, -- ID типа расписания
	node_type_src_id int4 NULL, -- ID типа объекта
	period_type_id int4 NULL, -- ID периодичности
	period_type_comment text NULL, -- Описание периодичности загрузки
	period_refresh_comment text NULL, -- Описание режима обновления данных
	now_ timestamptz NULL, -- Момент фиксации плана
	now_period_type_match bool NULL, -- Соответстсвие текущего периода и плана
	plan_ timestamp NULL, -- Дата и время планового запуска
	plan_next timestamp NULL, -- Дата и время следующего планового запуска
	now_plan_diff interval NULL, -- Разница между планом и моментом фиксации плана 
	pt_descr varchar(250) NULL, -- Периодичность
	every_times int4 NULL, -- Кол-во запусков
	plan_dt date NULL, -- Дата планового запуска
	plan_dt_next timestamp NULL, -- Дата следующего планового запуска
	plan_dt_prev timestamp NULL, -- Дата предыдущего планового запуска
	plan_prev timestamp NULL, -- Дата и время предыдущего планового запуска
	scheduler_id bpchar(10) NULL, -- ID расписания загрузки
	src_cd text NULL, -- Источник
	load_dttm timestamp(0) NULL, -- Дата загрузки
	wf_load_id numeric(22) NULL, -- ID потока
	eff_from_dttm timestamp NULL, -- Дата с
	eff_to_dttm timestamp NULL, -- Дата по
	last_seen_dttm timestamp NULL, -- Дата последнего просмотра
	is_wf_time_sched_active bool NULL -- Стоит на расписании
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (schema_src_id, node_src_id);

-- Column comments

COMMENT ON COLUMN dg_full.meta_scheduler_plan.schema_src_id IS 'Вершина - Схема';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.node_src_id IS 'Вершина - Объект';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.scheduler_type_src_id IS 'ID типа расписания';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.node_type_src_id IS 'ID типа объекта';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.period_type_id IS 'ID периодичности';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.period_type_comment IS 'Описание периодичности загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.period_refresh_comment IS 'Описание режима обновления данных';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.now_ IS 'Момент фиксации плана';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.now_period_type_match IS 'Соответстсвие текущего периода и плана';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.plan_ IS 'Дата и время планового запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.plan_next IS 'Дата и время следующего планового запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.now_plan_diff IS 'Разница между планом и моментом фиксации плана ';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.pt_descr IS 'Периодичность';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.every_times IS 'Кол-во запусков';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.plan_dt IS 'Дата планового запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.plan_dt_next IS 'Дата следующего планового запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.plan_dt_prev IS 'Дата предыдущего планового запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.plan_prev IS 'Дата и время предыдущего планового запуска';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.scheduler_id IS 'ID расписания загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.src_cd IS 'Источник';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.load_dttm IS 'Дата загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.wf_load_id IS 'ID потока';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.eff_from_dttm IS 'Дата с';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.eff_to_dttm IS 'Дата по';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.last_seen_dttm IS 'Дата последнего просмотра';
COMMENT ON COLUMN dg_full.meta_scheduler_plan.is_wf_time_sched_active IS 'Стоит на расписании';


-- dg_full.meta_scheduler_type_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_scheduler_type_ref_table;

CREATE TABLE dg_full.meta_scheduler_type_ref_table (
	scheduler_type_src_id varchar(250) NOT NULL, -- Id значения справочника
	descr varchar(250) NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (scheduler_type_src_id);
COMMENT ON TABLE dg_full.meta_scheduler_type_ref_table IS 'Тип запуска - ручной\автоматический';

-- Column comments

COMMENT ON COLUMN dg_full.meta_scheduler_type_ref_table.scheduler_type_src_id IS 'Id значения справочника';
COMMENT ON COLUMN dg_full.meta_scheduler_type_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_scheduler_type_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_type_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_scheduler_type_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_schema_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_schema_ref_table;

CREATE TABLE dg_full.meta_schema_ref_table (
	schema_src_id varchar(250) NOT NULL, -- Id схемы
	schema_cd varchar(100) NULL, -- Код схемы
	descr varchar(250) NULL, -- Описание
	"type" varchar(250) NULL, -- Тип среды - ЛД \ Пром
	schema_type varchar(250) NULL, -- Тип объекта - схема\категория\папка
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (schema_src_id);
COMMENT ON TABLE dg_full.meta_schema_ref_table IS 'Схемы, папки, категории CTL ';

-- Column comments

COMMENT ON COLUMN dg_full.meta_schema_ref_table.schema_src_id IS 'Id схемы';
COMMENT ON COLUMN dg_full.meta_schema_ref_table.schema_cd IS 'Код схемы';
COMMENT ON COLUMN dg_full.meta_schema_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_schema_ref_table."type" IS 'Тип среды - ЛД \ Пром';
COMMENT ON COLUMN dg_full.meta_schema_ref_table.schema_type IS 'Тип объекта - схема\категория\папка';
COMMENT ON COLUMN dg_full.meta_schema_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_schema_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_schema_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_schema_ref_table_manual definition

-- Drop table

-- DROP TABLE dg_full.meta_schema_ref_table_manual;

CREATE TABLE dg_full.meta_schema_ref_table_manual (
	schema_src_id varchar(250) NULL,
	schema_cd varchar(100) NULL,
	descr varchar(250) NULL,
	"type" varchar(250) NULL,
	schema_type varchar(250) NULL,
	load_dttm timestamp(0) NULL,
	wf_load_id numeric(22) NULL,
	src_cd varchar(20) NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_screen_link definition

-- Drop table

-- DROP TABLE dg_full.meta_screen_link;

CREATE TABLE dg_full.meta_screen_link (
	screen_id int4 NOT NULL, -- ID проверки
	screen_template_id int4 NOT NULL, -- ID проверки
	object_group_id int4 NOT NULL, -- ID группы объекта - проверяются в одном запросе
	processing_order int4 NULL, -- Последовательность запуска проверки - для одной группы совпадает
	etl_stage text NULL, -- Этап в ETL процессе, на котором проходит проверка
	default_severity_score float8 NULL, -- Оценка серьезности ошибки
	is_active int4 NULL, -- Флаг активности для проверки
	eff_from_dt date NULL, -- Начало действия
	eff_to_dt date NULL, -- Окончание действия
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	period_run text NULL, -- Периодичность проведения проверки: ctl, daily, weekly, monthly, on-demand
	exception_group_id int4 NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (screen_id);
COMMENT ON TABLE dg_full.meta_screen_link IS 'Список проверок, что они делают и когда запускаются';

-- Column comments

COMMENT ON COLUMN dg_full.meta_screen_link.screen_id IS 'ID проверки';
COMMENT ON COLUMN dg_full.meta_screen_link.screen_template_id IS 'ID проверки';
COMMENT ON COLUMN dg_full.meta_screen_link.object_group_id IS 'ID группы объекта - проверяются в одном запросе';
COMMENT ON COLUMN dg_full.meta_screen_link.processing_order IS 'Последовательность запуска проверки - для одной группы совпадает';
COMMENT ON COLUMN dg_full.meta_screen_link.etl_stage IS 'Этап в ETL процессе, на котором проходит проверка';
COMMENT ON COLUMN dg_full.meta_screen_link.default_severity_score IS 'Оценка серьезности ошибки';
COMMENT ON COLUMN dg_full.meta_screen_link.is_active IS 'Флаг активности для проверки';
COMMENT ON COLUMN dg_full.meta_screen_link.eff_from_dt IS 'Начало действия';
COMMENT ON COLUMN dg_full.meta_screen_link.eff_to_dt IS 'Окончание действия';
COMMENT ON COLUMN dg_full.meta_screen_link.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_screen_link.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_screen_link.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_screen_link.period_run IS 'Периодичность проведения проверки: ctl, daily, weekly, monthly, on-demand';


-- dg_full.meta_screen_link_manual definition

-- Drop table

-- DROP TABLE dg_full.meta_screen_link_manual;

CREATE TABLE dg_full.meta_screen_link_manual (
	screen_id int4 NULL,
	screen_template_id int4 NULL,
	object_group_id int4 NULL,
	processing_order int4 NULL,
	etl_stage text NULL,
	default_severity_score float8 NULL,
	is_active int4 NULL,
	eff_from_dt date NULL,
	eff_to_dt date NULL,
	load_dttm timestamp(0) NULL,
	wf_load_id numeric(22) NULL,
	src_cd varchar(20) NULL,
	period_run text NULL,
	exception_group_id int4 NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED RANDOMLY;


-- dg_full.meta_screen_template_alias_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_screen_template_alias_ref_table;

CREATE TABLE dg_full.meta_screen_template_alias_ref_table (
	screen_template_id int4 NOT NULL, -- ID проверки
	attribute_src_id text NULL, -- Заполнение переменными
	object_alias text NULL, -- Алиас объекта в шаблоне запроса
	object_order int4 NULL, -- Последовательность объектов
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	descr text NULL -- Бизнес описание
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (screen_template_id);
COMMENT ON TABLE dg_full.meta_screen_template_alias_ref_table IS 'Набор шаблонов-проверок, применяемых к различным полям-
Если проверка сложная и специфическая, то возможно прямое написание запроса.';

-- Column comments

COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.screen_template_id IS 'ID проверки';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.attribute_src_id IS 'Заполнение переменными';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.object_alias IS 'Алиас объекта в шаблоне запроса';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.object_order IS 'Последовательность объектов';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_screen_template_alias_ref_table.descr IS 'Бизнес описание';


-- dg_full.meta_screen_template_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_screen_template_ref_table;

CREATE TABLE dg_full.meta_screen_template_ref_table (
	screen_template_id int4 NOT NULL, -- ID проверки
	screen_sql text NULL, -- Проверочный запрос
	screen_type text NULL, -- Тип проверки
	screen_category text NULL, -- Категория проверки -  Incorrect, Ambiguous, Inconsistent, and Incomplete
	is_direct_sql int4 NULL, -- 0 - Подстановка алиасов {{..}}, 1 - Прямой запрос
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	descr text NULL, -- Бизнес описание
	priority_cd text NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (screen_template_id);
COMMENT ON TABLE dg_full.meta_screen_template_ref_table IS 'Набор шаблонов-проверок, применяемых к различным полям-
Если проверка сложная и специфическая, то возможно прямое написание запроса.';

-- Column comments

COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.screen_template_id IS 'ID проверки';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.screen_sql IS 'Проверочный запрос';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.screen_type IS 'Тип проверки';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.screen_category IS 'Категория проверки -  Incorrect, Ambiguous, Inconsistent, and Incomplete';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.is_direct_sql IS '0 - Подстановка алиасов {{..}}, 1 - Прямой запрос';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_screen_template_ref_table.descr IS 'Бизнес описание';


-- dg_full.meta_search_graph_target_all_obj definition

-- Drop table

-- DROP TABLE dg_full.meta_search_graph_target_all_obj;

CREATE TABLE dg_full.meta_search_graph_target_all_obj (
	node_id text NULL, -- Вершина
	node_type_cd varchar(20) NULL, -- Код типа объекта
	src_cd text NULL, -- Источник
	"depth" int4 NULL, -- Глубина иерархии
	root_node_id text NULL, -- Корневая вершина
	root_node_type_cd varchar(20) NULL, -- Код типа корневого объекта
	load_dttm timestamp(0) NULL, -- Дата загрузки
	wf_load_id numeric(22) NULL, -- ID потока
	eff_from_dttm timestamp NULL, -- Дата с
	eff_to_dttm timestamp NULL, -- Дата по
	last_seen_dttm timestamp NULL, -- Дата последнего просмотра
	node_src_id text NULL, -- Вершина - Объект
	schema_src_id text NULL, -- Вершина - Схема
	root_node_src_id text NULL, -- Корневая вершина - Объект
	root_schema_src_id text NULL, -- Корневая вершина - Схема
	root_is_active bool NULL, -- Признак активного корневого объекта
	is_active bool NULL -- Признак активного объекта
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (node_id);

-- Column comments

COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.node_id IS 'Вершина';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.node_type_cd IS 'Код типа объекта';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.src_cd IS 'Источник';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj."depth" IS 'Глубина иерархии';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.root_node_id IS 'Корневая вершина';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.root_node_type_cd IS 'Код типа корневого объекта';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.load_dttm IS 'Дата загрузки';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.wf_load_id IS 'ID потока';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.eff_from_dttm IS 'Дата с';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.eff_to_dttm IS 'Дата по';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.last_seen_dttm IS 'Дата последнего просмотра';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.node_src_id IS 'Вершина - Объект';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.schema_src_id IS 'Вершина - Схема';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.root_node_src_id IS 'Корневая вершина - Объект';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.root_schema_src_id IS 'Корневая вершина - Схема';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.root_is_active IS 'Признак активного корневого объекта';
COMMENT ON COLUMN dg_full.meta_search_graph_target_all_obj.is_active IS 'Признак активного объекта';


-- dg_full.meta_signal_link definition

-- Drop table

-- DROP TABLE dg_full.meta_signal_link;

CREATE TABLE dg_full.meta_signal_link (
	signal_id int8 NOT NULL, -- ID сигнала
	screen_template_id int4 NOT NULL, -- ID проверки \ формирование данных для сигнала
	object_group_id int4 NOT NULL, -- ID группы объектов - проверяются в одном запросе
	email_template_id int4 NOT NULL, -- ID текста письма с результатами сигнала
	signal_value_cd text NOT NULL, -- Значение сигнала, по которому выбирается текст письма для отправки
	processing_order int4 NULL, -- Последовательность запуска проверок - для одной группы совпадает
	default_severity_score float8 NULL, -- Оценка серьезности ошибки
	is_active int4 NULL, -- Флаг активности для проверки
	eff_from_dt date NULL, -- Начало действия
	eff_to_dt date NULL, -- Окончание действия
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	email_recipient_id int4 NULL, -- Идентификатор получателя
	attached_screen_id int8 NULL, -- Список screen_id для формирования вложений с итогами проверок
	html_screen_id int8 NULL -- Список screen_id для отображения  в теле письма
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=3
)
DISTRIBUTED BY (signal_id);
COMMENT ON TABLE dg_full.meta_signal_link IS 'Список сигналов, связь с проверками, что они делают и когда запускаются';

-- Column comments

COMMENT ON COLUMN dg_full.meta_signal_link.signal_id IS 'ID сигнала';
COMMENT ON COLUMN dg_full.meta_signal_link.screen_template_id IS 'ID проверки \ формирование данных для сигнала';
COMMENT ON COLUMN dg_full.meta_signal_link.object_group_id IS 'ID группы объектов - проверяются в одном запросе';
COMMENT ON COLUMN dg_full.meta_signal_link.email_template_id IS 'ID текста письма с результатами сигнала';
COMMENT ON COLUMN dg_full.meta_signal_link.signal_value_cd IS 'Значение сигнала, по которому выбирается текст письма для отправки';
COMMENT ON COLUMN dg_full.meta_signal_link.processing_order IS 'Последовательность запуска проверок - для одной группы совпадает';
COMMENT ON COLUMN dg_full.meta_signal_link.default_severity_score IS 'Оценка серьезности ошибки';
COMMENT ON COLUMN dg_full.meta_signal_link.is_active IS 'Флаг активности для проверки';
COMMENT ON COLUMN dg_full.meta_signal_link.eff_from_dt IS 'Начало действия';
COMMENT ON COLUMN dg_full.meta_signal_link.eff_to_dt IS 'Окончание действия';
COMMENT ON COLUMN dg_full.meta_signal_link.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_signal_link.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_signal_link.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_signal_link.email_recipient_id IS 'Идентификатор получателя';
COMMENT ON COLUMN dg_full.meta_signal_link.attached_screen_id IS 'Список screen_id для формирования вложений с итогами проверок';
COMMENT ON COLUMN dg_full.meta_signal_link.html_screen_id IS 'Список screen_id для отображения  в теле письма';


-- dg_full.meta_statistic_ref_table definition

-- Drop table

-- DROP TABLE dg_full.meta_statistic_ref_table;

CREATE TABLE dg_full.meta_statistic_ref_table (
	statistic_src_id int4 NOT NULL, -- Id статистики
	statistic_cd varchar(20) NULL, -- Код статистики
	descr varchar(250) NULL, -- Описание
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	src_cd varchar(20) NULL -- Код системы-источника
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (statistic_src_id);
COMMENT ON TABLE dg_full.meta_statistic_ref_table IS 'Справочник статистик';

-- Column comments

COMMENT ON COLUMN dg_full.meta_statistic_ref_table.statistic_src_id IS 'Id статистики';
COMMENT ON COLUMN dg_full.meta_statistic_ref_table.statistic_cd IS 'Код статистики';
COMMENT ON COLUMN dg_full.meta_statistic_ref_table.descr IS 'Описание';
COMMENT ON COLUMN dg_full.meta_statistic_ref_table.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_statistic_ref_table.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_statistic_ref_table.src_cd IS 'Код системы-источника';


-- dg_full.meta_sys_data_object_detail definition

-- Drop table

-- DROP TABLE dg_full.meta_sys_data_object_detail;

CREATE TABLE dg_full.meta_sys_data_object_detail (
	object_id int8 NULL,
	total_object_size numeric NULL,
	object_size numeric NULL,
	indexes_size numeric NULL,
	wf_load_id int8 NULL,
	inserted_dttm timestamp NULL
)
WITH (
	appendonly=true,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (object_id);


-- dg_full.meta_task_param_hsat definition

-- Drop table

-- DROP TABLE dg_full.meta_task_param_hsat;

CREATE TABLE dg_full.meta_task_param_hsat (
	event_param_id int4 NOT NULL, -- ID параметра загрузки 
	load_dttm timestamp(0) NULL, -- Дата и время загрузки
	src_cd varchar(20) NULL, -- Код системы-источника
	wf_load_id numeric(22) NULL, -- Идентификатор загрузки
	eff_from_dttm timestamp(0) NULL, -- Дата и время начала действия записи
	eff_to_dttm timestamp(0) NULL, -- Дата и время окончания действия записи
	last_seen_dttm timestamp(0) NULL, -- Дата и время обновления
	param_cd text NULL,
	param_name text NULL,
	param_val text NULL, -- Заданное значение
	node_src_id varchar(250) NULL,
	schema_src_id varchar(250) NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zlib,
	compresslevel=1
)
DISTRIBUTED BY (event_param_id);
COMMENT ON TABLE dg_full.meta_task_param_hsat IS 'Параметры запусков по потокам';

-- Column comments

COMMENT ON COLUMN dg_full.meta_task_param_hsat.event_param_id IS 'ID параметра загрузки ';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.load_dttm IS 'Дата и время загрузки';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.src_cd IS 'Код системы-источника';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.wf_load_id IS 'Идентификатор загрузки';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.eff_from_dttm IS 'Дата и время начала действия записи';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.eff_to_dttm IS 'Дата и время окончания действия записи';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.last_seen_dttm IS 'Дата и время обновления';
COMMENT ON COLUMN dg_full.meta_task_param_hsat.param_val IS 'Заданное значение';