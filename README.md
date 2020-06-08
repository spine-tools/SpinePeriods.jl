# SpinePeriods.jl

A package to run the representative days model described in:

K. Poncelet, H. Höschle, E. Delarue, A. Virag and W. D’haeseleer, "Selecting Representative Days for Capturing the Implications of Integrating Intermittent Renewables in Generation Expansion Planning Problems”, in IEEE Transactions on Power Systems, vol. 32, no. 3, pp. 1936-1948, May 2017.

and available [here](https://iea-etsap.org/projects/Timeslicetool%20V1.zip)

## Compatibility

This package requires Julia 1.2 or later.

## Installation

```julia
using Pkg
pkg"registry add https://github.com/Spine-project/SpineJuliaRegistry"
pkg"add SpinePeriods"
```

## Documentation

### Objective

The objective is to identify N representative periods which match the distribution of R resource/demand time series whose value range distribution is approximated by B blocks.

"Representative periods" are generic and the duration and resolution of the representative periods and are defined by a specific temporal block in the model. 

### Overview

Basically it works as follows :
 - A new object class `representative_period` is used to hold parameters related to the representative periods model. Similar to the model object, the tool picks the first representative period object it finds and the name doesn't matter.
 - The time series whose distributions are to be included for matching in the model are selected by creating `unit__representative_period` relationships, for `unit_availability_factor`, `unit__node__representative_period`s for `unit_capacity` and `node__representative_period` for `demand` at `nodes`. 
 - The tool calculates the distribution of each demand and resource availability time series over the whole model window and for each window (as defined by the temporal structure of the model). A single representative period is defined by the rolling window that SpineOpt creates and the distributions are calculated for each of these windows.
 - **Note** if the rolling structure contains an overlap period, or look ahead period, then the rolling distributions are matched. If this is not desired, one must make the `roll_forward` parameter of your model, equal to the window duration
 - The resolution of the distribution is controlled by the parameter `representative_blocks` on the `representative_period` object class
 - The number of representative periods to be matched is controlled by the parameter `representative_periods` on the `representative_period` object class
 - The JuMP optimisation model (using SpineOpt and SpineInterface) runs and the output of the solve is the selected days and their weights. 
 - The tool creates a copy of your DB and copies back into it, a number of `temporal_block`s corresponding to the representative periods chosen by the model.

Sample output :

```
[ Info: new database copied to 
D:\Workspace\Spine\Spinetoolbox\projects\Ireland_A1B1_2\.spinetoolbox\items\timeslice_tool_test\casestudy_a1_b1_3_rps_1.sqlite
[ Info: selected window: W68 with start 2000-03-08T00:00:00 and weight 47.65555412816721
[ Info: selected window: W81 with start 2000-03-21T00:00:00 and weight 24.412737183559916
[ Info: selected window: W85 with start 2000-03-25T00:00:00 and weight 16.936154595946654
[ Info: selected window: W95 with start 2000-04-04T00:00:00 and weight 12.03227506478919
[ Info: selected window: W175 with start 2000-06-23T00:00:00 and weight 15.451567656272331
[ Info: selected window: W188 with start 2000-07-06T00:00:00 and weight 16.82904234243774
[ Info: selected window: W208 with start 2000-07-26T00:00:00 and weight 23.264054127322495
[ Info: selected window: W209 with start 2000-07-27T00:00:00 and weight 11.67645440682964
[ Info: selected window: W211 with start 2000-07-29T00:00:00 and weight 24.145774884966958
[ Info: selected window: W216 with start 2000-08-03T00:00:00 and weight 16.197549691897688
[ Info: selected window: W238 with start 2000-08-25T00:00:00 and weight 24.144316861367635
[ Info: selected window: W326 with start 2000-11-21T00:00:00 and weight 7.254519056442569
```

### Usage
 - Create object in `representative_period` class
 - Create `node__representative_period` relationship for each `demand` time series you want to include
 - Create `unit__representative_period` relationship for each `unit_availability_factor` time series you want to include
 - Create `unit__node_representative_period` relationship for each `unit_capacity` time series you want to include
 - **Note**: Currently there is no check that the parameters are actually time series, it just gets their value for each timeslice and creates the distribution
 - Ensure that the rolling structure of your model corresponds to the representative periods you want to select. A single representative period will correspond to the rolling window that SpineOpt creates. 
 - Ensure your `model` `mode_start` and `mode_end` values capture the full optimisation horizon. If the rolling structure contains an overlap period, or look ahead period, then the rolling distributions are matched. If this is not desired, one must make the `roll_forward` parameter of your model, equal to the window duration.
 - Specify the distribution range resolution using `representative_blocks(representative_period)`
 - Specify the desired number of representative periods using `representative_periods(representative_period)`

### Positives
 - The model borrows from an existing SpineOpt model's temporal and rolling structure and produces consistent representative periods. The module re-uses Spine Model's rolling functions to move through the model horizon and evaluates resource distributions accordingly 
 - SpineInterface and Spine Model's temporal functions are used to determine the value for each included parameter's value in each timestep regardless of type. This means time patterned data can also be included for distribution matching
 - It all happens within Julia so GAMS is not required

### Questions
 - This is a new model - where should we put it in Gitlab? It's a tool, but it's also a model with a similar structure to Spine Model. We could consider it a companion model to SpineInterface

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

SpineOpt is licensed under GNU Lesser General Public License version 3.0 or later.