Benchmark

Envelope and round-trip cost over a 100-entry artifact, which the build
pays once per file written and the cache pays once per file on every
reload.


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
    <td style="white-space: nowrap">Artifact.envelope/1</td>
    <td style="white-space: nowrap; text-align: right">1092716.44</td>
    <td style="white-space: nowrap; text-align: right">0.00092 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;878.06%</td>
    <td style="white-space: nowrap; text-align: right">0.00079 ms</td>
    <td style="white-space: nowrap; text-align: right">0.00138 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap; text-align: right">196.79</td>
    <td style="white-space: nowrap; text-align: right">5.08 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.86%</td>
    <td style="white-space: nowrap; text-align: right">5.08 ms</td>
    <td style="white-space: nowrap; text-align: right">6.20 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap; text-align: right">147.07</td>
    <td style="white-space: nowrap; text-align: right">6.80 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.48%</td>
    <td style="white-space: nowrap; text-align: right">6.87 ms</td>
    <td style="white-space: nowrap; text-align: right">8.51 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Artifact.envelope/1</td>
    <td style="white-space: nowrap;text-align: right">1092716.44</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap; text-align: right">196.79</td>
    <td style="white-space: nowrap; text-align: right">5552.63x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap; text-align: right">147.07</td>
    <td style="white-space: nowrap; text-align: right">7430.07x</td>
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
    <td style="white-space: nowrap">Artifact.envelope/1</td>
    <td style="white-space: nowrap">0.00099 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap">7.30 MB</td>
    <td>7347.31x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap">7.40 MB</td>
    <td>7447.82x</td>
  </tr>
</table>