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
    <td style="white-space: nowrap">Apple M5 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">18</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">48 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.18.4</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">27.3.4.15</td>
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
    <td style="white-space: nowrap; text-align: right">9.78 K</td>
    <td style="white-space: nowrap; text-align: right">0.102 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.55%</td>
    <td style="white-space: nowrap; text-align: right">0.103 ms</td>
    <td style="white-space: nowrap; text-align: right">0.127 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">0.91 K</td>
    <td style="white-space: nowrap; text-align: right">1.10 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.32%</td>
    <td style="white-space: nowrap; text-align: right">1.10 ms</td>
    <td style="white-space: nowrap; text-align: right">1.19 ms</td>
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
    <td style="white-space: nowrap;text-align: right">9.78 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">0.91 K</td>
    <td style="white-space: nowrap; text-align: right">10.74x</td>
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
    <td style="white-space: nowrap">0.0717 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap">2.38 MB</td>
    <td>33.18x</td>
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
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">944.59</td>
    <td style="white-space: nowrap; text-align: right">1.06 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.79%</td>
    <td style="white-space: nowrap; text-align: right">1.04 ms</td>
    <td style="white-space: nowrap; text-align: right">1.34 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">904.26</td>
    <td style="white-space: nowrap; text-align: right">1.11 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.68%</td>
    <td style="white-space: nowrap; text-align: right">1.10 ms</td>
    <td style="white-space: nowrap; text-align: right">1.19 ms</td>
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
    <td style="white-space: nowrap;text-align: right">944.59</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">904.26</td>
    <td style="white-space: nowrap; text-align: right">1.04x</td>
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
    <td style="white-space: nowrap">0.73 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap">2.38 MB</td>
    <td>3.25x</td>
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
    <td style="white-space: nowrap; text-align: right">897.61</td>
    <td style="white-space: nowrap; text-align: right">1.11 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.95%</td>
    <td style="white-space: nowrap; text-align: right">1.11 ms</td>
    <td style="white-space: nowrap; text-align: right">1.20 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">159.61</td>
    <td style="white-space: nowrap; text-align: right">6.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.74%</td>
    <td style="white-space: nowrap; text-align: right">6.28 ms</td>
    <td style="white-space: nowrap; text-align: right">7.67 ms</td>
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
    <td style="white-space: nowrap;text-align: right">897.61</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">159.61</td>
    <td style="white-space: nowrap; text-align: right">5.62x</td>
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
    <td style="white-space: nowrap">2.38 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">3.69 MB</td>
    <td>1.55x</td>
  </tr>
</table>