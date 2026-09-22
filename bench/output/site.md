Benchmark

Site projection includes page admission, anchor and link resolution,
navigation, search, and digests. Static export includes rendering,
search serialization, link validation, staged writes, and replacement.
The destination is reused to measure the normal replacement path. Memory
figures are BEAM allocations reported by Benchee, not peak resident memory.

| Pages | Search records | Search bytes | Output files | Output bytes |
| ---: | ---: | ---: | ---: | ---: |
| 10 | 50 | 23182 | 19 | 41216 |
| 100 | 500 | 233112 | 109 | 392851 |
| 500 | 2500 | 1174062 | 509 | 1967950 |


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



__Input: 10 pages__

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
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap; text-align: right">245.50</td>
    <td style="white-space: nowrap; text-align: right">4.07 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.29%</td>
    <td style="white-space: nowrap; text-align: right">4.04 ms</td>
    <td style="white-space: nowrap; text-align: right">4.53 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">113.19</td>
    <td style="white-space: nowrap; text-align: right">8.83 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.15%</td>
    <td style="white-space: nowrap; text-align: right">8.81 ms</td>
    <td style="white-space: nowrap; text-align: right">10.65 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap;text-align: right">245.50</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">113.19</td>
    <td style="white-space: nowrap; text-align: right">2.17x</td>
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
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap">11.73 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">6.40 MB</td>
    <td>0.55x</td>
  </tr>
</table>



__Input: 100 pages__

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
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap; text-align: right">24.68</td>
    <td style="white-space: nowrap; text-align: right">40.52 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.82%</td>
    <td style="white-space: nowrap; text-align: right">40.27 ms</td>
    <td style="white-space: nowrap; text-align: right">42.81 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">15.39</td>
    <td style="white-space: nowrap; text-align: right">64.97 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.82%</td>
    <td style="white-space: nowrap; text-align: right">65.15 ms</td>
    <td style="white-space: nowrap; text-align: right">81.36 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap;text-align: right">24.68</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">15.39</td>
    <td style="white-space: nowrap; text-align: right">1.6x</td>
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
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap">117.13 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">62.31 MB</td>
    <td>0.53x</td>
  </tr>
</table>



__Input: 500 pages__

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
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap; text-align: right">4.88</td>
    <td style="white-space: nowrap; text-align: right">204.86 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.79%</td>
    <td style="white-space: nowrap; text-align: right">204.50 ms</td>
    <td style="white-space: nowrap; text-align: right">210.14 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">2.86</td>
    <td style="white-space: nowrap; text-align: right">349.09 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;12.35%</td>
    <td style="white-space: nowrap; text-align: right">338.92 ms</td>
    <td style="white-space: nowrap; text-align: right">504.04 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap;text-align: right">4.88</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">2.86</td>
    <td style="white-space: nowrap; text-align: right">1.7x</td>
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
    <td style="white-space: nowrap">SiteProjector.project/1</td>
    <td style="white-space: nowrap">585.74 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">311.04 MB</td>
    <td>0.53x</td>
  </tr>
</table>