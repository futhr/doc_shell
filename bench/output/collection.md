Benchmark

Collection preparation and complete filesystem import over increasing synthetic corpora. Setup and publication are outside timed work. Import includes bounded reads, JSON decoding, canonical hashes, shape validation and indexed provenance reconstruction. Memory is BEAM allocation measured by Benchee, not peak RSS. These are local measurements, not performance thresholds.

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
    <td style="white-space: nowrap">3 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">1 s</td>
  </tr>
</table>

## Statistics



__Input: 1000 documents__

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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap; text-align: right">394.19</td>
    <td style="white-space: nowrap; text-align: right">2.54 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.27%</td>
    <td style="white-space: nowrap; text-align: right">2.48 ms</td>
    <td style="white-space: nowrap; text-align: right">2.96 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">50.30</td>
    <td style="white-space: nowrap; text-align: right">19.88 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.86%</td>
    <td style="white-space: nowrap; text-align: right">19.84 ms</td>
    <td style="white-space: nowrap; text-align: right">21.64 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap;text-align: right">394.19</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">50.30</td>
    <td style="white-space: nowrap; text-align: right">7.84x</td>
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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap">6.75 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">41.61 MB</td>
    <td>6.17x</td>
  </tr>
</table>



__Input: 16000 documents__

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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap; text-align: right">16.32</td>
    <td style="white-space: nowrap; text-align: right">61.28 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.20%</td>
    <td style="white-space: nowrap; text-align: right">61.21 ms</td>
    <td style="white-space: nowrap; text-align: right">64.83 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">1.43</td>
    <td style="white-space: nowrap; text-align: right">697.78 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.72%</td>
    <td style="white-space: nowrap; text-align: right">687.29 ms</td>
    <td style="white-space: nowrap; text-align: right">778.24 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap;text-align: right">16.32</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">1.43</td>
    <td style="white-space: nowrap; text-align: right">11.39x</td>
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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap">109.82 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">672.02 MB</td>
    <td>6.12x</td>
  </tr>
</table>



__Input: 4000 documents__

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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap; text-align: right">96.21</td>
    <td style="white-space: nowrap; text-align: right">10.39 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.75%</td>
    <td style="white-space: nowrap; text-align: right">10.38 ms</td>
    <td style="white-space: nowrap; text-align: right">11.01 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">7.69</td>
    <td style="white-space: nowrap; text-align: right">130.01 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.41%</td>
    <td style="white-space: nowrap; text-align: right">131.33 ms</td>
    <td style="white-space: nowrap; text-align: right">135.35 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap;text-align: right">96.21</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">7.69</td>
    <td style="white-space: nowrap; text-align: right">12.51x</td>
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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap">27.13 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">167.11 MB</td>
    <td>6.16x</td>
  </tr>
</table>



__Input: 8000 documents__

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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap; text-align: right">43.56</td>
    <td style="white-space: nowrap; text-align: right">22.96 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.36%</td>
    <td style="white-space: nowrap; text-align: right">22.97 ms</td>
    <td style="white-space: nowrap; text-align: right">25.47 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">3.71</td>
    <td style="white-space: nowrap; text-align: right">269.22 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.01%</td>
    <td style="white-space: nowrap; text-align: right">268.85 ms</td>
    <td style="white-space: nowrap; text-align: right">276.30 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap;text-align: right">43.56</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">3.71</td>
    <td style="white-space: nowrap; text-align: right">11.73x</td>
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
    <td style="white-space: nowrap">Collection.prepare/2</td>
    <td style="white-space: nowrap">54.64 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">335.02 MB</td>
    <td>6.13x</td>
  </tr>
</table>