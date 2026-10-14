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
    <td style="white-space: nowrap">Apple M2</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">8</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">8 GB</td>
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
    <td style="white-space: nowrap; text-align: right">251.84</td>
    <td style="white-space: nowrap; text-align: right">3.97 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.57%</td>
    <td style="white-space: nowrap; text-align: right">3.86 ms</td>
    <td style="white-space: nowrap; text-align: right">4.52 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">35.37</td>
    <td style="white-space: nowrap; text-align: right">28.27 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.74%</td>
    <td style="white-space: nowrap; text-align: right">28.15 ms</td>
    <td style="white-space: nowrap; text-align: right">31.37 ms</td>
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
    <td style="white-space: nowrap;text-align: right">251.84</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">35.37</td>
    <td style="white-space: nowrap; text-align: right">7.12x</td>
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
    <td style="white-space: nowrap; text-align: right">11.81</td>
    <td style="white-space: nowrap; text-align: right">84.70 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;0.60%</td>
    <td style="white-space: nowrap; text-align: right">84.65 ms</td>
    <td style="white-space: nowrap; text-align: right">86.00 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">1.35</td>
    <td style="white-space: nowrap; text-align: right">740.20 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.11%</td>
    <td style="white-space: nowrap; text-align: right">737.94 ms</td>
    <td style="white-space: nowrap; text-align: right">754.11 ms</td>
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
    <td style="white-space: nowrap;text-align: right">11.81</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">1.35</td>
    <td style="white-space: nowrap; text-align: right">8.74x</td>
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
    <td style="white-space: nowrap; text-align: right">61.30</td>
    <td style="white-space: nowrap; text-align: right">16.31 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.68%</td>
    <td style="white-space: nowrap; text-align: right">16.17 ms</td>
    <td style="white-space: nowrap; text-align: right">23.79 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">6.51</td>
    <td style="white-space: nowrap; text-align: right">153.63 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.23%</td>
    <td style="white-space: nowrap; text-align: right">153.14 ms</td>
    <td style="white-space: nowrap; text-align: right">159.41 ms</td>
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
    <td style="white-space: nowrap;text-align: right">61.30</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">6.51</td>
    <td style="white-space: nowrap; text-align: right">9.42x</td>
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
    <td style="white-space: nowrap; text-align: right">29.32</td>
    <td style="white-space: nowrap; text-align: right">34.11 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.49%</td>
    <td style="white-space: nowrap; text-align: right">34.19 ms</td>
    <td style="white-space: nowrap; text-align: right">34.84 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">2.92</td>
    <td style="white-space: nowrap; text-align: right">342.51 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.06%</td>
    <td style="white-space: nowrap; text-align: right">341.53 ms</td>
    <td style="white-space: nowrap; text-align: right">350.03 ms</td>
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
    <td style="white-space: nowrap;text-align: right">29.32</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Collection.load/1</td>
    <td style="white-space: nowrap; text-align: right">2.92</td>
    <td style="white-space: nowrap; text-align: right">10.04x</td>
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