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
    <td style="white-space: nowrap; text-align: right">8.55 K</td>
    <td style="white-space: nowrap; text-align: right">117.02 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.09%</td>
    <td style="white-space: nowrap; text-align: right">111.15 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">242.18 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">8.55 K</td>
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
    <td style="white-space: nowrap">508.79 KB</td>
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
    <td style="white-space: nowrap; text-align: right">93.45 K</td>
    <td style="white-space: nowrap; text-align: right">10.70 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;25.98%</td>
    <td style="white-space: nowrap; text-align: right">10.08 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">20.13 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">93.45 K</td>
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
    <td style="white-space: nowrap">62.61 KB</td>
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
    <td style="white-space: nowrap; text-align: right">1.96 M</td>
    <td style="white-space: nowrap; text-align: right">509.08 ns</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;899.84%</td>
    <td style="white-space: nowrap; text-align: right">458 ns</td>
    <td style="white-space: nowrap; text-align: right">708 ns</td>
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
    <td style="white-space: nowrap;text-align: right">1.96 M</td>
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
    <td style="white-space: nowrap">2.97 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>