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
    <td style="white-space: nowrap; text-align: right">1193959.10</td>
    <td style="white-space: nowrap; text-align: right">0.00084 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;943.86%</td>
    <td style="white-space: nowrap; text-align: right">0.00058 ms</td>
    <td style="white-space: nowrap; text-align: right">0.00146 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap; text-align: right">295.71</td>
    <td style="white-space: nowrap; text-align: right">3.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.73%</td>
    <td style="white-space: nowrap; text-align: right">3.33 ms</td>
    <td style="white-space: nowrap; text-align: right">3.89 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap; text-align: right">26.75</td>
    <td style="white-space: nowrap; text-align: right">37.38 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.81%</td>
    <td style="white-space: nowrap; text-align: right">37.04 ms</td>
    <td style="white-space: nowrap; text-align: right">41.59 ms</td>
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
    <td style="white-space: nowrap;text-align: right">1193959.10</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap; text-align: right">295.71</td>
    <td style="white-space: nowrap; text-align: right">4037.59x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap; text-align: right">26.75</td>
    <td style="white-space: nowrap; text-align: right">44633.91x</td>
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
    <td style="white-space: nowrap">0.00140 MB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Artifact.read/1</td>
    <td style="white-space: nowrap">3.45 MB</td>
    <td>2466.99x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">Artifact.write/2</td>
    <td style="white-space: nowrap">30.37 MB</td>
    <td>21737.04x</td>
  </tr>
</table>