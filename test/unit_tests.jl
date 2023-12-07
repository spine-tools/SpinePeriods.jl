

function _load_test_data(db_url, test_data)
    data = Dict(Symbol(key) => value for (key, value) in SpineOpt.template())
    mergewith!(append!, data, Dict(Symbol(key) => value for (key, value) in SpinePeriods.template()), test_data)
    _load_test_data_without_template(db_url, data)
end

function _load_test_data_without_template(db_url, test_data)
    SpineInterface.close_connection(db_url)
    SpineInterface.open_connection(db_url)
    SpineInterface.import_data(db_url, "No comments"; test_data...)
end

function _test_data(m_start, m_end, rf, rps, method, for_rolling)
	res = Week(1)
	indices = collect(m_start:res:m_end)
	cycle = collect(1:100)
	cycle_count = ceil(Int, length(indices) / length(cycle))
	values = repeat(cycle, cycle_count)
	demand_ts = TimeSeries(indices, values)
	Dict(
		:objects => [
			("model", "spine_periods"),
			("representative_period", "rp"),
			("temporal_block", "year2017"),
			("node", "electricity"),
		],
		:relationships => [
			("node__representative_period", ("electricity", "rp")),
			("node__temporal_block", ("electricity", "year2017")),  # Add check for this
		],
		:object_parameter_values => [
			("representative_period", "rp", "representative_period_method", method),
			("representative_period", "rp", "representative_periods", rps),
			("representative_period", "rp", "for_rolling", for_rolling),
			("representative_period", "rp", "representative_blocks", 40),
			("model", "spine_periods", "model_start", unparse_db_value(m_start)),
			("model", "spine_periods", "model_end", unparse_db_value(m_end)),
			("model", "spine_periods", "roll_forward", unparse_db_value(rf)),
			("temporal_block", "year2017", "resolution", unparse_db_value(res)),
			("node", "electricity", "demand", unparse_db_value(demand_ts)),
		],
	)
end

function _run_spine_periods_selection()
	url_in = "sqlite://"
	m_start = DateTime(2017)
	m_end = DateTime(2018)
	rf = Week(4)	
	rps = 12
	test_data = _test_data(m_start, m_end, rf, rps, "representative_periods", false)
	_load_test_data(url_in, test_data)
	fp_out = "deleteme.sqlite"
	url_out = "sqlite:///$fp_out"
	rm(fp_out; force=true)
	run_spine_periods(url_in, url_out)
	Y = Module()
	using_spinedb(url_out, Y)
	exp_res = Day(7)
	exp_start_end = Dict(
		:rp_W1 => (DateTime("2017-01-01T00:00:00"), DateTime("2017-01-29T00:00:00")),
		:rp_W3 => (DateTime("2017-02-26T00:00:00"), DateTime("2017-03-26T00:00:00")),
		:rp_W4 => (DateTime("2017-03-26T00:00:00"), DateTime("2017-04-23T00:00:00")),
		:rp_W5 => (DateTime("2017-04-23T00:00:00"), DateTime("2017-05-21T00:00:00")),
		:rp_W6 => (DateTime("2017-05-21T00:00:00"), DateTime("2017-06-18T00:00:00")),
		:rp_W7 => (DateTime("2017-06-18T00:00:00"), DateTime("2017-07-16T00:00:00")),
		:rp_W8 => (DateTime("2017-07-16T00:00:00"), DateTime("2017-08-13T00:00:00")),
		:rp_W9 => (DateTime("2017-08-13T00:00:00"), DateTime("2017-09-10T00:00:00")),
		:rp_W10 => (DateTime("2017-09-10T00:00:00"), DateTime("2017-10-08T00:00:00")),
		:rp_W11 => (DateTime("2017-10-08T00:00:00"), DateTime("2017-11-05T00:00:00")),
		:rp_W12 => (DateTime("2017-11-05T00:00:00"), DateTime("2017-12-03T00:00:00")),
		:rp_W13 => (DateTime("2017-12-03T00:00:00"), DateTime("2017-12-31T00:00:00")),
	)
	exp_weight = Dict(
		:rp_W1 => 2.4999999999999867,
		:rp_W3 => 1.3333333333333466,
		:rp_W4 => 0.8888888888888877,
		:rp_W5 => 1.0370370370367956,
		:rp_W6 => 0.9876543209881475,
		:rp_W7 => 1.004115226337116,
		:rp_W8 => 0.998628257887626,
		:rp_W9 => 1.0004572473707893,
		:rp_W11 => 1.0000762078951393,
		:rp_W10 => 0.9998475842097362,
		:rp_W12 => 0.9998475842097077,
		:rp_W13 => 1.2501143118427198,
	)
	repr_blocks = [tb for tb in Y.temporal_block() if !(tb.name in (:all_representative_periods, :year2017))]
	@test length(repr_blocks) == rps
	@testset for tb in repr_blocks
		@test Y.resolution(temporal_block=tb) == exp_res
		@test (Y.block_start(temporal_block=tb), Y.block_end(temporal_block=tb)) == exp_start_end[tb.name]
		@test isapprox(Y.weight(temporal_block=tb), exp_weight[tb.name])
	end
end

function _run_spine_periods_ordering()
	url_in = "sqlite://"
	m_start = DateTime(2017)
	m_end = DateTime(2018)
	rf = Week(4)	
	rps = 12
	test_data = _test_data(m_start, m_end, rf, rps, "representative_periods_ordering", false)
	_load_test_data(url_in, test_data)
	fp_out = "deleteme.sqlite"
	url_out = "sqlite:///$fp_out"
	rm(fp_out; force=true)
	run_spine_periods(url_in, url_out)
	Y = Module()
	using_spinedb(url_out, Y)
	exp_res = Day(7)
	exp_start_end = Dict(
		:rp_W1 => (DateTime("2017-01-01T00:00:00"), DateTime("2017-01-29T00:00:00")),
		:rp_W2 => (DateTime("2017-01-29T00:00:00"), DateTime("2017-02-26T00:00:00")),
		:rp_W4 => (DateTime("2017-03-26T00:00:00"), DateTime("2017-04-23T00:00:00")),
		:rp_W5 => (DateTime("2017-04-23T00:00:00"), DateTime("2017-05-21T00:00:00")),
		:rp_W6 => (DateTime("2017-05-21T00:00:00"), DateTime("2017-06-18T00:00:00")),
		:rp_W7 => (DateTime("2017-06-18T00:00:00"), DateTime("2017-07-16T00:00:00")),
		:rp_W8 => (DateTime("2017-07-16T00:00:00"), DateTime("2017-08-13T00:00:00")),
		:rp_W10 => (DateTime("2017-09-10T00:00:00"), DateTime("2017-10-08T00:00:00")),
		:rp_W11 => (DateTime("2017-10-08T00:00:00"), DateTime("2017-11-05T00:00:00")),
		:rp_W12 => (DateTime("2017-11-05T00:00:00"), DateTime("2017-12-03T00:00:00")),
		:rp_W13 => (DateTime("2017-12-03T00:00:00"), DateTime("2017-12-31T00:00:00")),
		:rp_W14 => (DateTime("2017-12-31T00:00:00"), DateTime("2018-01-28T00:00:00")),
	)
	exp_weight = Dict(
		:rp_W1 => 1,
		:rp_W2 => 2,
		:rp_W4 => 1,
		:rp_W5 => 1,
		:rp_W6 => 1,
		:rp_W7 => 1,
		:rp_W8 => 2,
		:rp_W10 => 1,
		:rp_W11 => 1,
		:rp_W12 => 1,
		:rp_W13 => 1,
		:rp_W14 => 1,
	)
	repr_blocks = [tb for tb in Y.temporal_block() if !(tb.name in (:all_representative_periods, :year2017))]
	@test length(repr_blocks) == rps
	@testset for tb in repr_blocks
		@test Y.resolution(temporal_block=tb) == exp_res
		@test (Y.block_start(temporal_block=tb), Y.block_end(temporal_block=tb)) == exp_start_end[tb.name]
		@test isapprox(Y.weight(temporal_block=tb), exp_weight[tb.name])
	end
end

function _run_spine_periods_ordering_for_rolling()
	url_in = "sqlite://"
	m_start = DateTime(2017)
	m_end = DateTime(2018)
	rf = Week(4)	
	rps = 12
	test_data = _test_data(m_start, m_end, rf, rps, "representative_periods_ordering", true)
	_load_test_data(url_in, test_data)
	fp_out = "deleteme.sqlite"
	url_out = "sqlite:///$fp_out"
	rm(fp_out; force=true)
	run_spine_periods(url_in, url_out)
	Y = Module()
	using_spinedb(url_out, Y)
	exp_m_start = DateTime("2017-01-01T00:00:00")
	exp_rf = [Week(4), Week(8), Week(4), Week(4), Week(4), Week(4), Week(8), Week(4), Week(4), Week(4), Week(4)]
	exp_w_starts = collect(m_start:rf:m_end)
	exp_repr_w_starts = [
		DateTime("2017-01-01T00:00:00"),
		DateTime("2017-01-29T00:00:00"),
		DateTime("2017-01-29T00:00:00"),
		DateTime("2017-03-26T00:00:00"),
		DateTime("2017-04-23T00:00:00"),
		DateTime("2017-05-21T00:00:00"),
		DateTime("2017-06-18T00:00:00"),
		DateTime("2017-07-16T00:00:00"),
		DateTime("2017-07-16T00:00:00"),
		DateTime("2017-09-10T00:00:00"),
		DateTime("2017-10-08T00:00:00"),
		DateTime("2017-11-05T00:00:00"),
		DateTime("2017-12-03T00:00:00"),
		DateTime("2017-12-31T00:00:00"),
	]
	@test Y.model_start(model=first(Y.model())) == exp_m_start
	@test Y.roll_forward(model=first(Y.model())) == exp_rf
	@test Y.window_duration(model=first(Y.model())) == Week(4)
	for (w_start, repr_w_start) in zip(exp_w_starts, exp_repr_w_starts)
		@test Y.representative_windows_mapping(model=first(Y.model()), d=w_start) == repr_w_start
	end
end



