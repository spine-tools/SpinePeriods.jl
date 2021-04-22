# SpinePeriods.jl

A package to run the optimisation based representative period models described in [this working paper](https://www.mech.kuleuven.be/en/tme/research/energy-systems-integration-modeling/pdf-publications/wp-esim2021-1).

## Compatibility

Fill in once testing is setup.

## Installation

```julia
using Pkg
pkg"registry add https://github.com/Spine-project/SpineJuliaRegistry"
pkg"add SpinePeriods"
```

## TODO List

* Comment on the two different selection methods
* Update documentation for use
* Running from toolbox
* The length of a representative period is defined by the `roll_forward` duration, so this has to be defined.

## Documentation

### Step by step setup

1. Import your time series into the database
2. Setup your `model` object - specify the start and end of the time series and the `roll_forward` parameter, e.g. to 1D (this last bit is quite important)
3. Specify your time series resolution in a `temporal_block` object in the database.
4. Create a `representative_period` object. Add relationships to units and nodes (see below). You can also specify model options (such as number of representative periods to select) here.
5. From Julia run `SpinePeriods.run_spine_periods(<sqlite_file>)`.

### Issues
 - Currently the representative period model input data resides alongside regular Spine Model data which I know @marenihlemann doesn't like. However, it's a small amount of data and currently we can view data from multiple data stores simultaneously (but I don't think we can create relationships between different datastores?) In the future, perhaps we can make provision for storing the RP data seperately. The issue described in https://gitlab.vtt.fi/spine/toolbox/-/issues/688 relates

### Possible enhancements
 - Option to automatically include all timeseries type parameters in the distribution matching
 - Option to automatically include all time pattern type parameters in the distribution matching
 - Option to exclude window overlaps

### Next Steps
 - Include investment variables and run and investment model over a set of representative days


## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

Complete once license is done.
