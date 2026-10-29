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
    <td style="white-space: nowrap; text-align: right">357.14</td>
    <td style="white-space: nowrap; text-align: right">2.80 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;10.65%</td>
    <td style="white-space: nowrap; text-align: right">2.71 ms</td>
    <td style="white-space: nowrap; text-align: right">3.57 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">35.70</td>
    <td style="white-space: nowrap; text-align: right">28.01 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.49%</td>
    <td style="white-space: nowrap; text-align: right">29.70 ms</td>
    <td style="white-space: nowrap; text-align: right">40.48 ms</td>
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
    <td style="white-space: nowrap;text-align: right">357.14</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">35.70</td>
    <td style="white-space: nowrap; text-align: right">10.0x</td>
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
    <td style="white-space: nowrap">4.98 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">32.70 MB</td>
    <td>6.57x</td>
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
    <td style="white-space: nowrap; text-align: right">15.38</td>
    <td style="white-space: nowrap; text-align: right">65.03 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.49%</td>
    <td style="white-space: nowrap; text-align: right">64.91 ms</td>
    <td style="white-space: nowrap; text-align: right">67.29 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">1.82</td>
    <td style="white-space: nowrap; text-align: right">549.02 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.90%</td>
    <td style="white-space: nowrap; text-align: right">548.82 ms</td>
    <td style="white-space: nowrap; text-align: right">562.43 ms</td>
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
    <td style="white-space: nowrap;text-align: right">15.38</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">1.82</td>
    <td style="white-space: nowrap; text-align: right">8.44x</td>
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
    <td style="white-space: nowrap">81.57 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">530.61 MB</td>
    <td>6.51x</td>
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
    <td style="white-space: nowrap; text-align: right">85.99</td>
    <td style="white-space: nowrap; text-align: right">11.63 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.74%</td>
    <td style="white-space: nowrap; text-align: right">11.64 ms</td>
    <td style="white-space: nowrap; text-align: right">12.21 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">8.77</td>
    <td style="white-space: nowrap; text-align: right">114.07 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.61%</td>
    <td style="white-space: nowrap; text-align: right">115.33 ms</td>
    <td style="white-space: nowrap; text-align: right">120.74 ms</td>
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
    <td style="white-space: nowrap;text-align: right">85.99</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">8.77</td>
    <td style="white-space: nowrap; text-align: right">9.81x</td>
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
    <td style="white-space: nowrap">20.14 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">131.68 MB</td>
    <td>6.54x</td>
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
    <td style="white-space: nowrap; text-align: right">40.41</td>
    <td style="white-space: nowrap; text-align: right">24.74 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.86%</td>
    <td style="white-space: nowrap; text-align: right">24.72 ms</td>
    <td style="white-space: nowrap; text-align: right">25.69 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">2.29</td>
    <td style="white-space: nowrap; text-align: right">436.99 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;28.05%</td>
    <td style="white-space: nowrap; text-align: right">494.97 ms</td>
    <td style="white-space: nowrap; text-align: right">575.07 ms</td>
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
    <td style="white-space: nowrap;text-align: right">40.41</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">2.29</td>
    <td style="white-space: nowrap; text-align: right">17.66x</td>
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
    <td style="white-space: nowrap">40.54 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap">264.25 MB</td>
    <td>6.52x</td>
  </tr>
</table>