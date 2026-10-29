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
    <td style="white-space: nowrap; text-align: right">152.44</td>
    <td style="white-space: nowrap; text-align: right">6.56 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.27%</td>
    <td style="white-space: nowrap; text-align: right">6.53 ms</td>
    <td style="white-space: nowrap; text-align: right">7.39 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">56.25</td>
    <td style="white-space: nowrap; text-align: right">17.78 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.17%</td>
    <td style="white-space: nowrap; text-align: right">17.57 ms</td>
    <td style="white-space: nowrap; text-align: right">25.24 ms</td>
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
    <td style="white-space: nowrap;text-align: right">152.44</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">56.25</td>
    <td style="white-space: nowrap; text-align: right">2.71x</td>
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
    <td style="white-space: nowrap">12.05 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">9.85 MB</td>
    <td>0.82x</td>
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
    <td style="white-space: nowrap; text-align: right">13.10</td>
    <td style="white-space: nowrap; text-align: right">76.34 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.01%</td>
    <td style="white-space: nowrap; text-align: right">74.69 ms</td>
    <td style="white-space: nowrap; text-align: right">96.98 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">6.78</td>
    <td style="white-space: nowrap; text-align: right">147.52 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.16%</td>
    <td style="white-space: nowrap; text-align: right">143.75 ms</td>
    <td style="white-space: nowrap; text-align: right">219.08 ms</td>
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
    <td style="white-space: nowrap;text-align: right">13.10</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">6.78</td>
    <td style="white-space: nowrap; text-align: right">1.93x</td>
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
    <td style="white-space: nowrap">120.37 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">96.42 MB</td>
    <td>0.8x</td>
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
    <td style="white-space: nowrap; text-align: right">2.60</td>
    <td style="white-space: nowrap; text-align: right">384.30 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;29.16%</td>
    <td style="white-space: nowrap; text-align: right">336.71 ms</td>
    <td style="white-space: nowrap; text-align: right">671.85 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">1.07</td>
    <td style="white-space: nowrap; text-align: right">938.06 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.01%</td>
    <td style="white-space: nowrap; text-align: right">851.34 ms</td>
    <td style="white-space: nowrap; text-align: right">1257.19 ms</td>
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
    <td style="white-space: nowrap;text-align: right">2.60</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">1.07</td>
    <td style="white-space: nowrap; text-align: right">2.44x</td>
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
    <td style="white-space: nowrap">602.02 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">481.42 MB</td>
    <td>0.8x</td>
  </tr>
</table>