Benchmark

`stringify/1` runs over every piece of metadata in every module and node,
so it is called far more often than anything else here and its cost is
dominated by tree depth.


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



__Input: deep (depth 8)__

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
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap; text-align: right">13.18 K</td>
    <td style="white-space: nowrap; text-align: right">75.86 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;17.20%</td>
    <td style="white-space: nowrap; text-align: right">70 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">133.38 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap;text-align: right">13.18 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap">297.18 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: nested (depth 5)__

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
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap; text-align: right">134.05 K</td>
    <td style="white-space: nowrap; text-align: right">7.46 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;45.94%</td>
    <td style="white-space: nowrap; text-align: right">7.04 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">15.96 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap;text-align: right">134.05 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap">36.50 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: shallow (depth 1)__

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
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap; text-align: right">2.74 M</td>
    <td style="white-space: nowrap; text-align: right">364.87 ns</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1357.20%</td>
    <td style="white-space: nowrap; text-align: right">333 ns</td>
    <td style="white-space: nowrap; text-align: right">500 ns</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap;text-align: right">2.74 M</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">Json.stringify/1</td>
    <td style="white-space: nowrap">1.73 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>