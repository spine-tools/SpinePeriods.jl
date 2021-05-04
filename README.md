# SpinePeriods.jl

A package to run the optimisation based representative period models described in [this working paper](https://www.mech.kuleuven.be/en/tme/research/energy-systems-integration-modeling/pdf-publications/wp-esim2021-1).

## Compatibility

Fill in once testing has been setup.

## Installation

```julia
using Pkg
pkg"registry add https://github.com/Spine-project/SpineJuliaRegistry"
pkg"add SpinePeriods"
```

## Documentation

### Step by step setup

1. Import your time series into the database
2. Setup your `model` object - specify the start and end of the time series and the `roll_forward` parameter, e.g. to 1D. This determines the length of the periods which will be selected.
3. Specify your time series resolution in a `temporal_block` object in the database.
4. Create a `representative_period` object. Add relationships to units and nodes (see below). You can also specify model options (such as number of representative periods to select) here.
5. From Julia:
```julia
db_url = sqlite:///<path_to_your_database>
json_output = <output_file>.json 
db_url_out = sqlite:///<output_database>
run_spine_periods(
    db_url,
    json_output, # replace this with `db_url_out` to write results to a database
    with_optimizer=Cbc.Optimizer
)
```

### Detailed

#### Model choice

Two models are possible to select representative periods, `representative_periods` and `representative_periods_ordering`, defined as the parameter `representative_period_method` in a `representative_period` object. They are both described in [this working paper](https://www.mech.kuleuven.be/en/tme/research/energy-systems-integration-modeling/pdf-publications/wp-esim2021-1) where they are referred to as **ORDF** and **ORDO** respectively.
* `representative_periods` simply selects representative periods.
* `representative_periods_ordering` also order representative periods throughout the year so that long term storage arbitrage can be modeled (see [this section of the SpineOpt documentation](https://spine-project.github.io/SpineOpt.jl/latest/advanced_concepts/representative_days_w_seasonal_storage/)).

#### Time series input

The selection (and ordering) requires time series. To select which time series to be used, a relationship for these must be made with `representative_periods`, e.g. `node__representative_period`. Current time series considered are:
* `demand`
* `unit_availability_factor` 
* `unit_capacity`

#### Options
- `representative_periods` - Number of representative periods to be selected (and ordered).
- `representative_blocks` - Discretisation level of the duration curves used for the `representative_periods` ordering method, i.e. not relevant for `representative_periods_ordering`. Higher leads to more accuracy, lower speeds up computation time.

### Troubleshooting and known issues
* You will probably need to load `src/representative_periods_template.json` into your Spine database before being able to start specifying representative periods, options etc.
* Having several temporal blocks in your database will confuse SpinePeriods as to which one to use.
* Selecting and ordering periods of lengths smaller than days (e.g. hours) could make Julia crash. This should not be the case when only selecting periods.
* Similarly, selecting (and ordering) from several years could lead to Julia crashing if the optimisation problem becomes too large.


## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

SpineOpt is licensed under GNU Lesser General Public License version 3.0 or later.