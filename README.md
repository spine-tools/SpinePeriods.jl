# SpinePeriods.jl

A package to run the optimisation based representative period models described in [this working paper](https://www.mech.kuleuven.be/en/tme/research/energy-systems-integration-modeling/pdf-publications/wp-esim2021-1).

## Compatibility

Fill in once testing has been setup.

## Installation

```julia
using Pkg
pkg"registry add https://github.com/Spine-tools/SpineJuliaRegistry"
pkg"add SpinePeriods"
```

## Usage

Assuming you have a working SpineOpt database, do the following:


1. Load the SpineOpt periods template from `src/representative_periods_template.json` into your SpineOpt database.
1. Setup your `model` object; specify `model_start` and `model_end` as well as `roll_forward` - the latter determines the length of the periods that will be selected.
1. Create a `representative_period` object (only one `representative_period` object is needed; if you create two or more, only one of them will be used and you wouldn't know which one.)
1. Specify the value of the `representative_period_method` parameter for your `representative_period` object, wich determines the method for the representative periods model. Two values are possible:
    - `representative_periods` simply selects representative periods.
    - `representative_periods_ordering` also orders representative periods throughout the year so that long term storage arbitrage can be modeled (see [this section of the SpineOpt documentation](https://spine-tools.github.io/SpineOpt.jl/latest/advanced_concepts/representative_days_w_seasonal_storage/)).

    The two methods are described in [this working paper](https://www.mech.kuleuven.be/en/tme/research/energy-systems-integration-modeling/pdf-publications/wp-esim2021-1) where they are referred to as **ORDF** and **ORDO** respectively.

1. Specify the value of `representative_periods` and `representative_blocks` for your `representative_period` object:
    - `representative_periods` is the number of representative periods to be selected (and ordered).
    - `representative_blocks` is the discretisation level of the duration curves used for the `representative_periods_ordering` method, i.e. not relevant for the `representative_periods` method. Higher leads to more accuracy; lower reduces problem size and speeds up computation.

1. Create `unit__representative_period`, `node__representative_period` and `unit__node__representative_period` relationships between your `representative_period` object, and the `unit`s and `node`s that you want to include in the representative periods model. The relationships you create determine the parameter values used to select (and order) representative periods according to the table below.

    | relationship | parameter |
    | --- | --- |
    | `unit__representative_period` | `unit_availability_factor` for the `unit`|
    | `node__representative_period` | `demand` for the `node`|
    | `unit__node__representative_period` | `unit_capacity` for both the `unit__from_node` and `unit__to_node` |

1. Optionally specify `representative_period_weight` for the above relationships. This determines the weight SpinePeriods will assign to the corresponding parameter value in the optimisation model. It defaults to 1.


1. You're ready to go! From Julia:
    ```julia
    db_url = "sqlite:///<path_to_your_database>"
    json_output = "<output_file>.json" 
    db_url_out = "sqlite:///<output_database>"
    run_spine_periods(
        db_url,
        json_output, # replace this with `db_url_out` to write results to a database
        with_optimizer=HiGHS.Optimizer
    )
    ```

1. Let SpinePeriods cook. The output data will be a copy of the input with the following additions/modifications:

    - One `temporal_block` object for each selected representative period will be created.
    - The value of `roll_forward` will be set to `null` (because in general, representative periods are more useful with non-rolling models).
    - Finally, if you selected the `representative_periods_ordering` method, then the value of the `representative_periods_mapping` parameter will be set for each `temporal_block` associated to the `unit`s and `node`s in your representative periods model (as per step 6 above), to a `map` value that [SpineOpt will like](https://spine-tools.github.io/SpineOpt.jl/latest/advanced_concepts/representative_days_w_seasonal_storage/).

    With the above, the database will be ready to be used with the representative periods implementation in SpineOpt.

### Troubleshooting and known issues
* Selecting and ordering periods of lengths smaller than days (e.g. hours) could make Julia crash. This should not be the case when only selecting periods.
* Similarly, selecting (and ordering) from several years could lead to Julia crashing if the optimisation problem becomes too large.


## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

SpineOpt is licensed under GNU Lesser General Public License version 3.0 or later.
