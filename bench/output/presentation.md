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
    <td style="white-space: nowrap">GraphProjector.validate/1</td>
    <td style="white-space: nowrap; text-align: right">175.92 K</td>
    <td style="white-space: nowrap; text-align: right">5.68 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;74.30%</td>
    <td style="white-space: nowrap; text-align: right">5.63 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">7.79 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">37.88 K</td>
    <td style="white-space: nowrap; text-align: right">26.40 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;12.92%</td>
    <td style="white-space: nowrap; text-align: right">25.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">40.13 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">175.92 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">37.88 K</td>
    <td style="white-space: nowrap; text-align: right">4.64x</td>
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
    <td style="white-space: nowrap">4.08 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">47.54 KB</td>
    <td>11.66x</td>
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
    <td style="white-space: nowrap; text-align: right">170.95 K</td>
    <td style="white-space: nowrap; text-align: right">5.85 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;74.65%</td>
    <td style="white-space: nowrap; text-align: right">5.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">8.25 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">4.03 K</td>
    <td style="white-space: nowrap; text-align: right">248.08 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.60%</td>
    <td style="white-space: nowrap; text-align: right">247 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">292.60 &micro;s</td>
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
    <td style="white-space: nowrap;text-align: right">170.95 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">4.03 K</td>
    <td style="white-space: nowrap; text-align: right">42.41x</td>
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
    <td style="white-space: nowrap">4.08 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">477.02 KB</td>
    <td>116.97x</td>
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
    <td style="white-space: nowrap; text-align: right">172.69 K</td>
    <td style="white-space: nowrap; text-align: right">0.00579 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;84.49%</td>
    <td style="white-space: nowrap; text-align: right">0.00567 ms</td>
    <td style="white-space: nowrap; text-align: right">0.00804 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">0.50 K</td>
    <td style="white-space: nowrap; text-align: right">2.00 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;39.25%</td>
    <td style="white-space: nowrap; text-align: right">1.44 ms</td>
    <td style="white-space: nowrap; text-align: right">3.39 ms</td>
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
    <td style="white-space: nowrap;text-align: right">172.69 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap; text-align: right">0.50 K</td>
    <td style="white-space: nowrap; text-align: right">345.37x</td>
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
    <td style="white-space: nowrap">0.00398 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticGenerator.project/1</td>
    <td style="white-space: nowrap">2.34 MB</td>
    <td>588.49x</td>
  </tr>
</table>