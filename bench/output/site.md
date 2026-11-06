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
    <td style="white-space: nowrap; text-align: right">147.48</td>
    <td style="white-space: nowrap; text-align: right">6.78 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.83%</td>
    <td style="white-space: nowrap; text-align: right">6.62 ms</td>
    <td style="white-space: nowrap; text-align: right">9.58 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">2.15</td>
    <td style="white-space: nowrap; text-align: right">465.45 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;122.95%</td>
    <td style="white-space: nowrap; text-align: right">83.53 ms</td>
    <td style="white-space: nowrap; text-align: right">1419.24 ms</td>
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
    <td style="white-space: nowrap;text-align: right">147.48</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">2.15</td>
    <td style="white-space: nowrap; text-align: right">68.64x</td>
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
    <td style="white-space: nowrap">12.06 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">10.73 MB</td>
    <td>0.89x</td>
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
    <td style="white-space: nowrap; text-align: right">9.58</td>
    <td style="white-space: nowrap; text-align: right">104.40 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;66.46%</td>
    <td style="white-space: nowrap; text-align: right">83.56 ms</td>
    <td style="white-space: nowrap; text-align: right">418.33 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">4.70</td>
    <td style="white-space: nowrap; text-align: right">212.73 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;16.29%</td>
    <td style="white-space: nowrap; text-align: right">202.64 ms</td>
    <td style="white-space: nowrap; text-align: right">361.92 ms</td>
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
    <td style="white-space: nowrap;text-align: right">9.58</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">4.70</td>
    <td style="white-space: nowrap; text-align: right">2.04x</td>
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
    <td style="white-space: nowrap">120.49 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">104.71 MB</td>
    <td>0.87x</td>
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
    <td style="white-space: nowrap; text-align: right">2.38</td>
    <td style="white-space: nowrap; text-align: right">419.44 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;33.76%</td>
    <td style="white-space: nowrap; text-align: right">349.84 ms</td>
    <td style="white-space: nowrap; text-align: right">772.57 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">1.14</td>
    <td style="white-space: nowrap; text-align: right">876.05 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;26.08%</td>
    <td style="white-space: nowrap; text-align: right">734.80 ms</td>
    <td style="white-space: nowrap; text-align: right">1184.75 ms</td>
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
    <td style="white-space: nowrap;text-align: right">2.38</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap; text-align: right">1.14</td>
    <td style="white-space: nowrap; text-align: right">2.09x</td>
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
    <td style="white-space: nowrap">602.61 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">StaticExporter.export/1</td>
    <td style="white-space: nowrap">522.57 MB</td>
    <td>0.87x</td>
  </tr>
</table>