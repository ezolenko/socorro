create or replace function reports_clean_weekly_partition (
	this_date timestamptz, which_table text )
returns text
language plpgsql
set timezone = 'UTC'
as $f$
-- this function, meant to be called internally
-- checks if the correct reports_clean or reports_user_info partition exists
-- otherwise it creates it
-- returns the name of the partition
declare this_part text;
	begin_week text;
	end_week text;
	rc_indexes text[];
	dex int := 1;
begin
	this_part := which_table || '_' || to_char(date_trunc('week', this_date), 'YYYYMMDD');
	begin_week := to_char(date_trunc('week', this_date), 'YYYY-MM-DD');
	end_week := to_char(date_trunc('week', this_date) + interval '1 week', 'YYYY-MM-DD');
	
	PERFORM 1
	FROM pg_stat_user_tables
	WHERE relname = this_part;
	IF FOUND THEN
		RETURN this_part;
	END IF;
	
	EXECUTE 'CREATE TABLE ' || this_part || $$
		( CONSTRAINT date_processed_week CHECK ( date_processed >= '$$ || begin_week || $$'::timestamp AT TIME ZONE 'UTC'
			AND date_processed < '$$ || end_week || $$'::timestamp AT TIME ZONE 'UTC' ) )
		INHERITS ( $$ || which_table || $$ );$$;
	EXECUTE 'CREATE UNIQUE INDEX ' || this_part || '_uuid ON ' || this_part || '(uuid);';

	IF which_table = 'reports_clean' THEN

		rc_indexes := ARRAY[ 'date_processed', 'product_version_id', 'os_name', 'os_version_id', 
			'signature_id', 'address_id', 'flash_version_id', 'hang_id', 'process_type', 'release_channel', 'domain_id' ];
			
	ELSEIF which_table = 'reports_user_info' THEN
	
		rc_indexes := '{}';
	
	END IF;
	
	WHILE rc_indexes[dex] IS NOT NULL LOOP
		EXECUTE 'CREATE INDEX ' || this_part || '_' || rc_indexes[dex]
			|| ' ON ' || this_part || '(' || rc_indexes[dex] || ');';
		dex := dex + 1;
	END LOOP;
	
	RETURN this_part;
end;$f$;