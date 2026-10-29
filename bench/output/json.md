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
    <td style="white-space: nowrap; text-align: right">7.82 K</td>
    <td style="white-space: nowrap; text-align: right">127.81 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;32.41%</td>
    <td style="white-space: nowrap; text-align: right">112.33 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">278.83 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">7.82 K</td>
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
    <td style="white-space: nowrap">438.84 KB</td>
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
    <td style="white-space: nowrap; text-align: right">86.21 K</td>
    <td style="white-space: nowrap; text-align: right">11.60 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;35.27%</td>
    <td style="white-space: nowrap; text-align: right">11.29 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">14.63 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">86.21 K</td>
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
    <td style="white-space: nowrap">54.02 KB</td>
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
    <td style="white-space: nowrap; text-align: right">1.77 M</td>
    <td style="white-space: nowrap; text-align: right">565.89 ns</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;742.26%</td>
    <td style="white-space: nowrap; text-align: right">500 ns</td>
    <td style="white-space: nowrap; text-align: right">750 ns</td>
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
    <td style="white-space: nowrap;text-align: right">1.77 M</td>
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
    <td style="white-space: nowrap">2.55 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>