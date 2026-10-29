Benchmark

Markdown parsing runs once per document and is the hottest path in a
build: every module doc, guide, and notebook goes through it. Inputs span
a terse module doc to a long guide.


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



__Input: large (50 sections)__

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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap; text-align: right">41.23</td>
    <td style="white-space: nowrap; text-align: right">24.25 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.04%</td>
    <td style="white-space: nowrap; text-align: right">24.37 ms</td>
    <td style="white-space: nowrap; text-align: right">26.52 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap;text-align: right">41.23</td>
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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap">16.78 MB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: medium (10 sections)__

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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap; text-align: right">235.37</td>
    <td style="white-space: nowrap; text-align: right">4.25 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;2.00%</td>
    <td style="white-space: nowrap; text-align: right">4.24 ms</td>
    <td style="white-space: nowrap; text-align: right">4.50 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap;text-align: right">235.37</td>
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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap">3.22 MB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: small (1 section)__

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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap; text-align: right">2.16 K</td>
    <td style="white-space: nowrap; text-align: right">462.82 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.10%</td>
    <td style="white-space: nowrap; text-align: right">457 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">567.69 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap;text-align: right">2.16 K</td>
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
    <td style="white-space: nowrap">Ast.from_markdown/1</td>
    <td style="white-space: nowrap">340.42 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>