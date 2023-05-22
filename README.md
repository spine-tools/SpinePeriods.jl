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

Assuming you have a working SpineOpt database:


1. Load the SpineOpt periods template from `src/representative_periods_template.json` into your SpineOpt database.
1. Setup your `model` object; specify `model_start` and `model_end` as well as `roll_forward` - which determines the candidate periods for the model. In short, what SpineOpt would see as optimization windows, SpinePeriods sees as candidate periods.
1. Create a `representative_period` object (only one `representative_period` object is needed; if you create two or more, only one of them will be used and you wouldn't know which one.)
1. Specify the value of the `representative_period_method` parameter for your `representative_period` object, which determines the method for the representative periods model. Two values are possible:
    - `representative_periods` simply selects representative periods.
    - `representative_periods_ordering` also orders representative periods throughout the optimisation horizon so that long term storage arbitrage can be modeled (see [this section of the SpineOpt documentation](https://spine-tools.github.io/SpineOpt.jl/latest/advanced_concepts/representative_days_w_seasonal_storage/)).

    The two methods are described in [this working paper](https://www.mech.kuleuven.be/en/tme/research/energy-systems-integration-modeling/pdf-publications/wp-esim2021-1) where they are referred to as **ORDF** and **ORDO** respectively.

1. Specify the value of the `representative_periods` and `representative_blocks` parameters for your `representative_period` object:
    - `representative_periods` is the number of representative periods to be selected (and ordered).
    - `representative_blocks` is the discretisation level of the duration curves used for the `representative_periods_ordering` method, i.e. not relevant for the `representative_periods` method. Higher leads to more accuracy; lower reduces problem size and speeds up computation.

1. Specify the value of the `for_rolling` Boolean parameter for your `representative_period` object, which determines whether or not the output of SpinePeriods should be a SpineOpt DB ready to run a rolling horizon optimization on the selected representative periods (as if they were successive).

1. Create `unit__representative_period`, `node__representative_period` and `unit__node__representative_period` relationships between your `representative_period` object, and the `unit`s and `node`s that you want to include in the representative periods model. The relationships you create determine the parameter values used to select (and order) representative periods according to the table below.

    | relationship | parameter |
    | --- | --- |
    | `unit__representative_period` | `unit_availability_factor` for the `unit`|
    | `node__representative_period` | `demand` for the `node`|
    | `unit__node__representative_period` | `unit_capacity` for both the `unit__from_node` and `unit__to_node` |

1. Optionally specify `representative_period_weight` for the above relationships. This determines the weight SpinePeriods will assign to the corresponding parameter value in the optimisation model. It defaults to 1.


1. You're ready to go! From Julia:
    ```julia
    db_url_in = "sqlite:///<path_to_your_input_database>"
    db_url_out = "sqlite:///<path_to_your_output_database>"
    json_out = "<path_to_your_output_file>.json" 
    run_spine_periods(
        db_url_in,
        db_url_out, # replace this with `json_out` to write results to a JSON file
        with_optimizer=HiGHS.Optimizer
    )
    ```

1. Let SpinePeriods cook. The output database will be a copy of the input with a few additions/modifications depending on the value of the `for_rolling` parameter:

    - If `for rolling` is `false`:

        - One `temporal_block` object for each selected representative period will be created. These `temporal_block`s will also be associated to each `unit` and `node` included in your representative periods model (according to step 6 above) via `units_on__temporal_block` and `node__temporal_block`, respectively.
        - The value of `roll_forward` will be set to `null`.
        - For each `temporal_block` *originally* associated to any `unit`s and `node`s included your representative periods model (as per step 6 above), if the value of `block_end` is a duration then it will be adjusted to reflect the fact that the model won't be rolling anymore.
        - Finally, if you selected the `representative_periods_ordering` method, then for each `temporal_block` *originally* associated to any `unit`s and `node`s included in your representative periods model (as per step 6 above), the value of the `representative_periods_mapping` parameter will be set to a `map` that [SpineOpt will like](https://spine-tools.github.io/SpineOpt.jl/latest/advanced_concepts/representative_days_w_seasonal_storage/).

    - If `for rolling` is `true`:
        - The value of `model_start` for your model object will be set to the start of the first representative period selected.
        - The value of `roll_forward` will be set to an array of duration values, thus allowing SpineOpt to roll over the selected representative periods.

    In either case, the database will be ready to be used by SpineOpt.

### Troubleshooting and known issues
* Selecting and ordering periods of lengths smaller than days (e.g. hours) could make Julia crash. This should not be the case when only selecting periods.
* Similarly, selecting (and ordering) from several years could lead to Julia crashing if the optimisation problem becomes too large.


## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

SpinePeriods is licensed under GNU Lesser General Public License version 3.0 or later.
