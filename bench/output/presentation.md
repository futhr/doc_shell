Benchmark

Projection runs once per build over every entry at once, so it scales with
the size of the documentation set rather than with any one document.
Validation is measured alongside it because graph-backed hosts pay for it
on every projector call — it reads a fixed 100-entry presentation and so
does not vary with the input.


## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Max</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">16</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">128 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.20.4</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">29.0.4</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">5 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



__Input: 10 entries__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">7.20 K</td>
    <td style="white-space: nowrap; text-align: right">0.139 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.64%</td>
    <td style="white-space: nowrap; text-align: right">0.139 ms</td>
    <td style="white-space: nowrap; text-align: right">0.175 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">0.72 K</td>
    <td style="white-space: nowrap; text-align: right">1.39 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.33%</td>
    <td style="white-space: nowrap; text-align: right">1.38 ms</td>
    <td style="white-space: nowrap; text-align: right">1.48 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap;text-align: right">7.20 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">0.72 K</td>
    <td style="white-space: nowrap; text-align: right">9.99x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">0.0683 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap">2.27 MB</td>
    <td>33.24x</td>
  </tr>
</table>



__Input: 100 entries__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">721.85</td>
    <td style="white-space: nowrap; text-align: right">1.39 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.74%</td>
    <td style="white-space: nowrap; text-align: right">1.38 ms</td>
    <td style="white-space: nowrap; text-align: right">1.48 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">705.41</td>
    <td style="white-space: nowrap; text-align: right">1.42 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.09%</td>
    <td style="white-space: nowrap; text-align: right">1.40 ms</td>
    <td style="white-space: nowrap; text-align: right">1.68 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap;text-align: right">721.85</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">705.41</td>
    <td style="white-space: nowrap; text-align: right">1.02x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap">2.27 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">0.70 MB</td>
    <td>0.31x</td>
  </tr>
</table>



__Input: 500 entries__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Deviation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">723.32</td>
    <td style="white-space: nowrap; text-align: right">1.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.09%</td>
    <td style="white-space: nowrap; text-align: right">1.38 ms</td>
    <td style="white-space: nowrap; text-align: right">1.50 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">114.32</td>
    <td style="white-space: nowrap; text-align: right">8.75 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.26%</td>
    <td style="white-space: nowrap; text-align: right">8.16 ms</td>
    <td style="white-space: nowrap; text-align: right">10.38 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap;text-align: right">723.32</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">114.32</td>
    <td style="white-space: nowrap; text-align: right">6.33x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap">2.27 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">3.53 MB</td>
    <td>1.55x</td>
  </tr>
</table>