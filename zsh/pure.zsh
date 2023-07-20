<!DOCTYPE html>

<html lang="en">
<head>
<meta charset="utf8"/>
<meta content="width=device-width, initial-scale=1" name="viewport"/>
<title>~cdv/pure-prompt: pure.zsh - sourcehut git</title>
<link href="/static/logo.svg" rel="icon" type="image/svg+xml"/>
<link href="/static/logo.png" rel="icon" sizes="any" type="image/png"/>
<link href="/static/main.min.a7e88522.css" rel="stylesheet"/>
<style>
pre {
  tab-size: 8
}
</style>
<meta content="git" name="vcs"/>
<meta content="https://git.sr.ht/~cdv/pure-prompt" name="vcs:clone"/>
<meta content="git@git.sr.ht:~cdv/pure-prompt" name="vcs:clone"/>
<meta content="https://git.sr.ht/~cdv/pure-prompt" name="forge:summary"/>
<meta content="https://git.sr.ht/~cdv/pure-prompt/tree/{ref}/item/{path}" name="forge:dir"/>
<meta content="https://git.sr.ht/~cdv/pure-prompt/tree/{ref}/item/{path}" name="forge:file"/>
<meta content="https://git.sr.ht/~cdv/pure-prompt/blob/{ref}/{path}" name="forge:rawfile"/>
<meta content="https://git.sr.ht/~cdv/pure-prompt/tree/{ref}/item/{path}#L{line}" name="forge:line"/>
<meta content="git.sr.ht/~cdv/pure-prompt git https://git.sr.ht/~cdv/pure-prompt" name="go-import"/>
</head>
<body>
<nav class="navbar navbar-light navbar-expand-sm">
<span class="navbar-brand">
<span aria-hidden="true" class="icon icon-circle"><svg height="22" viewbox="0 0 512 512" width="22" xmlns="http://www.w3.org/2000/svg"><path d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm0 448c-110.5 0-200-89.5-200-200S145.5 56 256 56s200 89.5 200 200-89.5 200-200 200z"></path></svg>
</span>
<a href="https://sr.ht">
    sourcehut
  </a>
</span>
<ul class="navbar-nav">
</ul>
<div class="login">
<span class="navbar-text">
<a href="https://meta.sr.ht/oauth/authorize?client_id=25ff6e5ce60d7345&amp;scopes=profile,keys,b99a95de3e69c958/jobs:write&amp;state=%2F~cdv%2Fpure-prompt%2Ftree%2Fac72ba4eb274e7181b7db677838409adb190266e%2Fpure.zsh%3F" rel="nofollow">Log in</a>
    —
    <a href="https://meta.sr.ht">Register</a>
</span>
</div>
</nav>
<div class="header-tabbed">
<div class="container-fluid">
<h2>
<a href="/~cdv/">~cdv</a>/<wbr/>pure-prompt
    </h2>
<ul class="nav nav-tabs">
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt">summary</a>
</li>
<li class="nav-item">
<a class="nav-link active" href="/~cdv/pure-prompt/tree">tree</a>
</li>
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt/log">log</a>
</li>
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt/refs">refs</a>
</li>
</ul>
</div>
</div>
<div class="header-extension" style="margin-bottom: 0;">
<div class="blob container-fluid">
<span>
<span style="margin-right: 1rem">
<span class="text-muted">ref:</span> ac72ba4eb274e7181b7db677838409adb190266e
</span>
<a href="/~cdv/pure-prompt/tree/ac72ba4eb274e7181b7db677838409adb190266e">pure-prompt</a>/pure.zsh



  
  
  <span class="text-muted" style="margin-left: 1rem">
<span title="100644">
      -rw-r--r--
    </span>
</span>
<span class="text-muted" style="margin-left: 1rem">
<span title="23890 bytes">
        23.3 KiB
      </span>
</span>
<div class="blob-nav" style="margin-left: 1rem">
<ul class="nav nav-tabs">
<li class="nav-item">
<a class="nav-link active" href="/~cdv/pure-prompt/tree/ac72ba4eb274e7181b7db677838409adb190266e/item/pure.zsh">View</a>
</li>
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt/log/ac72ba4eb274e7181b7db677838409adb190266e/item/pure.zsh">Log</a>
</li>
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt/blame/ac72ba4eb274e7181b7db677838409adb190266e/pure.zsh">Blame</a>
</li>
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt/blob/ac72ba4eb274e7181b7db677838409adb190266e/pure.zsh" rel="noopener noreferrer nofollow">View raw</a>
</li>
<li class="nav-item">
<a class="nav-link" href="/~cdv/pure-prompt/tree/ac72ba4eb274e7181b7db677838409adb190266e">Permalink</a>
</li>
</ul>
</div>
</span>
<div class="commit">
<a href="/~cdv/pure-prompt/commit/ac72ba4eb274e7181b7db677838409adb190266e">ac72ba4e</a> —
      
      
      Mathias Fredriksson
      
      1.10.3
      <span class="text-muted">
<span title="2019-06-25 12:43:00 UTC">4 years ago</span>
</span>
</div>
<div class="clearfix"></div>
</div>
</div>
<div class="container-fluid code-viewport">
<div class="row" style="margin-right: 0;">
<div class="col-md-12 code-view">
<pre class="ruler"><span>                                                                                </span></pre>
<pre class="lines"><a href="#L1" id="L1">1</a>
<a href="#L2" id="L2">2</a>
<a href="#L3" id="L3">3</a>
<a href="#L4" id="L4">4</a>
<a href="#L5" id="L5">5</a>
<a href="#L6" id="L6">6</a>
<a href="#L7" id="L7">7</a>
<a href="#L8" id="L8">8</a>
<a href="#L9" id="L9">9</a>
<a href="#L10" id="L10">10</a>
<a href="#L11" id="L11">11</a>
<a href="#L12" id="L12">12</a>
<a href="#L13" id="L13">13</a>
<a href="#L14" id="L14">14</a>
<a href="#L15" id="L15">15</a>
<a href="#L16" id="L16">16</a>
<a href="#L17" id="L17">17</a>
<a href="#L18" id="L18">18</a>
<a href="#L19" id="L19">19</a>
<a href="#L20" id="L20">20</a>
<a href="#L21" id="L21">21</a>
<a href="#L22" id="L22">22</a>
<a href="#L23" id="L23">23</a>
<a href="#L24" id="L24">24</a>
<a href="#L25" id="L25">25</a>
<a href="#L26" id="L26">26</a>
<a href="#L27" id="L27">27</a>
<a href="#L28" id="L28">28</a>
<a href="#L29" id="L29">29</a>
<a href="#L30" id="L30">30</a>
<a href="#L31" id="L31">31</a>
<a href="#L32" id="L32">32</a>
<a href="#L33" id="L33">33</a>
<a href="#L34" id="L34">34</a>
<a href="#L35" id="L35">35</a>
<a href="#L36" id="L36">36</a>
<a href="#L37" id="L37">37</a>
<a href="#L38" id="L38">38</a>
<a href="#L39" id="L39">39</a>
<a href="#L40" id="L40">40</a>
<a href="#L41" id="L41">41</a>
<a href="#L42" id="L42">42</a>
<a href="#L43" id="L43">43</a>
<a href="#L44" id="L44">44</a>
<a href="#L45" id="L45">45</a>
<a href="#L46" id="L46">46</a>
<a href="#L47" id="L47">47</a>
<a href="#L48" id="L48">48</a>
<a href="#L49" id="L49">49</a>
<a href="#L50" id="L50">50</a>
<a href="#L51" id="L51">51</a>
<a href="#L52" id="L52">52</a>
<a href="#L53" id="L53">53</a>
<a href="#L54" id="L54">54</a>
<a href="#L55" id="L55">55</a>
<a href="#L56" id="L56">56</a>
<a href="#L57" id="L57">57</a>
<a href="#L58" id="L58">58</a>
<a href="#L59" id="L59">59</a>
<a href="#L60" id="L60">60</a>
<a href="#L61" id="L61">61</a>
<a href="#L62" id="L62">62</a>
<a href="#L63" id="L63">63</a>
<a href="#L64" id="L64">64</a>
<a href="#L65" id="L65">65</a>
<a href="#L66" id="L66">66</a>
<a href="#L67" id="L67">67</a>
<a href="#L68" id="L68">68</a>
<a href="#L69" id="L69">69</a>
<a href="#L70" id="L70">70</a>
<a href="#L71" id="L71">71</a>
<a href="#L72" id="L72">72</a>
<a href="#L73" id="L73">73</a>
<a href="#L74" id="L74">74</a>
<a href="#L75" id="L75">75</a>
<a href="#L76" id="L76">76</a>
<a href="#L77" id="L77">77</a>
<a href="#L78" id="L78">78</a>
<a href="#L79" id="L79">79</a>
<a href="#L80" id="L80">80</a>
<a href="#L81" id="L81">81</a>
<a href="#L82" id="L82">82</a>
<a href="#L83" id="L83">83</a>
<a href="#L84" id="L84">84</a>
<a href="#L85" id="L85">85</a>
<a href="#L86" id="L86">86</a>
<a href="#L87" id="L87">87</a>
<a href="#L88" id="L88">88</a>
<a href="#L89" id="L89">89</a>
<a href="#L90" id="L90">90</a>
<a href="#L91" id="L91">91</a>
<a href="#L92" id="L92">92</a>
<a href="#L93" id="L93">93</a>
<a href="#L94" id="L94">94</a>
<a href="#L95" id="L95">95</a>
<a href="#L96" id="L96">96</a>
<a href="#L97" id="L97">97</a>
<a href="#L98" id="L98">98</a>
<a href="#L99" id="L99">99</a>
<a href="#L100" id="L100">100</a>
<a href="#L101" id="L101">101</a>
<a href="#L102" id="L102">102</a>
<a href="#L103" id="L103">103</a>
<a href="#L104" id="L104">104</a>
<a href="#L105" id="L105">105</a>
<a href="#L106" id="L106">106</a>
<a href="#L107" id="L107">107</a>
<a href="#L108" id="L108">108</a>
<a href="#L109" id="L109">109</a>
<a href="#L110" id="L110">110</a>
<a href="#L111" id="L111">111</a>
<a href="#L112" id="L112">112</a>
<a href="#L113" id="L113">113</a>
<a href="#L114" id="L114">114</a>
<a href="#L115" id="L115">115</a>
<a href="#L116" id="L116">116</a>
<a href="#L117" id="L117">117</a>
<a href="#L118" id="L118">118</a>
<a href="#L119" id="L119">119</a>
<a href="#L120" id="L120">120</a>
<a href="#L121" id="L121">121</a>
<a href="#L122" id="L122">122</a>
<a href="#L123" id="L123">123</a>
<a href="#L124" id="L124">124</a>
<a href="#L125" id="L125">125</a>
<a href="#L126" id="L126">126</a>
<a href="#L127" id="L127">127</a>
<a href="#L128" id="L128">128</a>
<a href="#L129" id="L129">129</a>
<a href="#L130" id="L130">130</a>
<a href="#L131" id="L131">131</a>
<a href="#L132" id="L132">132</a>
<a href="#L133" id="L133">133</a>
<a href="#L134" id="L134">134</a>
<a href="#L135" id="L135">135</a>
<a href="#L136" id="L136">136</a>
<a href="#L137" id="L137">137</a>
<a href="#L138" id="L138">138</a>
<a href="#L139" id="L139">139</a>
<a href="#L140" id="L140">140</a>
<a href="#L141" id="L141">141</a>
<a href="#L142" id="L142">142</a>
<a href="#L143" id="L143">143</a>
<a href="#L144" id="L144">144</a>
<a href="#L145" id="L145">145</a>
<a href="#L146" id="L146">146</a>
<a href="#L147" id="L147">147</a>
<a href="#L148" id="L148">148</a>
<a href="#L149" id="L149">149</a>
<a href="#L150" id="L150">150</a>
<a href="#L151" id="L151">151</a>
<a href="#L152" id="L152">152</a>
<a href="#L153" id="L153">153</a>
<a href="#L154" id="L154">154</a>
<a href="#L155" id="L155">155</a>
<a href="#L156" id="L156">156</a>
<a href="#L157" id="L157">157</a>
<a href="#L158" id="L158">158</a>
<a href="#L159" id="L159">159</a>
<a href="#L160" id="L160">160</a>
<a href="#L161" id="L161">161</a>
<a href="#L162" id="L162">162</a>
<a href="#L163" id="L163">163</a>
<a href="#L164" id="L164">164</a>
<a href="#L165" id="L165">165</a>
<a href="#L166" id="L166">166</a>
<a href="#L167" id="L167">167</a>
<a href="#L168" id="L168">168</a>
<a href="#L169" id="L169">169</a>
<a href="#L170" id="L170">170</a>
<a href="#L171" id="L171">171</a>
<a href="#L172" id="L172">172</a>
<a href="#L173" id="L173">173</a>
<a href="#L174" id="L174">174</a>
<a href="#L175" id="L175">175</a>
<a href="#L176" id="L176">176</a>
<a href="#L177" id="L177">177</a>
<a href="#L178" id="L178">178</a>
<a href="#L179" id="L179">179</a>
<a href="#L180" id="L180">180</a>
<a href="#L181" id="L181">181</a>
<a href="#L182" id="L182">182</a>
<a href="#L183" id="L183">183</a>
<a href="#L184" id="L184">184</a>
<a href="#L185" id="L185">185</a>
<a href="#L186" id="L186">186</a>
<a href="#L187" id="L187">187</a>
<a href="#L188" id="L188">188</a>
<a href="#L189" id="L189">189</a>
<a href="#L190" id="L190">190</a>
<a href="#L191" id="L191">191</a>
<a href="#L192" id="L192">192</a>
<a href="#L193" id="L193">193</a>
<a href="#L194" id="L194">194</a>
<a href="#L195" id="L195">195</a>
<a href="#L196" id="L196">196</a>
<a href="#L197" id="L197">197</a>
<a href="#L198" id="L198">198</a>
<a href="#L199" id="L199">199</a>
<a href="#L200" id="L200">200</a>
<a href="#L201" id="L201">201</a>
<a href="#L202" id="L202">202</a>
<a href="#L203" id="L203">203</a>
<a href="#L204" id="L204">204</a>
<a href="#L205" id="L205">205</a>
<a href="#L206" id="L206">206</a>
<a href="#L207" id="L207">207</a>
<a href="#L208" id="L208">208</a>
<a href="#L209" id="L209">209</a>
<a href="#L210" id="L210">210</a>
<a href="#L211" id="L211">211</a>
<a href="#L212" id="L212">212</a>
<a href="#L213" id="L213">213</a>
<a href="#L214" id="L214">214</a>
<a href="#L215" id="L215">215</a>
<a href="#L216" id="L216">216</a>
<a href="#L217" id="L217">217</a>
<a href="#L218" id="L218">218</a>
<a href="#L219" id="L219">219</a>
<a href="#L220" id="L220">220</a>
<a href="#L221" id="L221">221</a>
<a href="#L222" id="L222">222</a>
<a href="#L223" id="L223">223</a>
<a href="#L224" id="L224">224</a>
<a href="#L225" id="L225">225</a>
<a href="#L226" id="L226">226</a>
<a href="#L227" id="L227">227</a>
<a href="#L228" id="L228">228</a>
<a href="#L229" id="L229">229</a>
<a href="#L230" id="L230">230</a>
<a href="#L231" id="L231">231</a>
<a href="#L232" id="L232">232</a>
<a href="#L233" id="L233">233</a>
<a href="#L234" id="L234">234</a>
<a href="#L235" id="L235">235</a>
<a href="#L236" id="L236">236</a>
<a href="#L237" id="L237">237</a>
<a href="#L238" id="L238">238</a>
<a href="#L239" id="L239">239</a>
<a href="#L240" id="L240">240</a>
<a href="#L241" id="L241">241</a>
<a href="#L242" id="L242">242</a>
<a href="#L243" id="L243">243</a>
<a href="#L244" id="L244">244</a>
<a href="#L245" id="L245">245</a>
<a href="#L246" id="L246">246</a>
<a href="#L247" id="L247">247</a>
<a href="#L248" id="L248">248</a>
<a href="#L249" id="L249">249</a>
<a href="#L250" id="L250">250</a>
<a href="#L251" id="L251">251</a>
<a href="#L252" id="L252">252</a>
<a href="#L253" id="L253">253</a>
<a href="#L254" id="L254">254</a>
<a href="#L255" id="L255">255</a>
<a href="#L256" id="L256">256</a>
<a href="#L257" id="L257">257</a>
<a href="#L258" id="L258">258</a>
<a href="#L259" id="L259">259</a>
<a href="#L260" id="L260">260</a>
<a href="#L261" id="L261">261</a>
<a href="#L262" id="L262">262</a>
<a href="#L263" id="L263">263</a>
<a href="#L264" id="L264">264</a>
<a href="#L265" id="L265">265</a>
<a href="#L266" id="L266">266</a>
<a href="#L267" id="L267">267</a>
<a href="#L268" id="L268">268</a>
<a href="#L269" id="L269">269</a>
<a href="#L270" id="L270">270</a>
<a href="#L271" id="L271">271</a>
<a href="#L272" id="L272">272</a>
<a href="#L273" id="L273">273</a>
<a href="#L274" id="L274">274</a>
<a href="#L275" id="L275">275</a>
<a href="#L276" id="L276">276</a>
<a href="#L277" id="L277">277</a>
<a href="#L278" id="L278">278</a>
<a href="#L279" id="L279">279</a>
<a href="#L280" id="L280">280</a>
<a href="#L281" id="L281">281</a>
<a href="#L282" id="L282">282</a>
<a href="#L283" id="L283">283</a>
<a href="#L284" id="L284">284</a>
<a href="#L285" id="L285">285</a>
<a href="#L286" id="L286">286</a>
<a href="#L287" id="L287">287</a>
<a href="#L288" id="L288">288</a>
<a href="#L289" id="L289">289</a>
<a href="#L290" id="L290">290</a>
<a href="#L291" id="L291">291</a>
<a href="#L292" id="L292">292</a>
<a href="#L293" id="L293">293</a>
<a href="#L294" id="L294">294</a>
<a href="#L295" id="L295">295</a>
<a href="#L296" id="L296">296</a>
<a href="#L297" id="L297">297</a>
<a href="#L298" id="L298">298</a>
<a href="#L299" id="L299">299</a>
<a href="#L300" id="L300">300</a>
<a href="#L301" id="L301">301</a>
<a href="#L302" id="L302">302</a>
<a href="#L303" id="L303">303</a>
<a href="#L304" id="L304">304</a>
<a href="#L305" id="L305">305</a>
<a href="#L306" id="L306">306</a>
<a href="#L307" id="L307">307</a>
<a href="#L308" id="L308">308</a>
<a href="#L309" id="L309">309</a>
<a href="#L310" id="L310">310</a>
<a href="#L311" id="L311">311</a>
<a href="#L312" id="L312">312</a>
<a href="#L313" id="L313">313</a>
<a href="#L314" id="L314">314</a>
<a href="#L315" id="L315">315</a>
<a href="#L316" id="L316">316</a>
<a href="#L317" id="L317">317</a>
<a href="#L318" id="L318">318</a>
<a href="#L319" id="L319">319</a>
<a href="#L320" id="L320">320</a>
<a href="#L321" id="L321">321</a>
<a href="#L322" id="L322">322</a>
<a href="#L323" id="L323">323</a>
<a href="#L324" id="L324">324</a>
<a href="#L325" id="L325">325</a>
<a href="#L326" id="L326">326</a>
<a href="#L327" id="L327">327</a>
<a href="#L328" id="L328">328</a>
<a href="#L329" id="L329">329</a>
<a href="#L330" id="L330">330</a>
<a href="#L331" id="L331">331</a>
<a href="#L332" id="L332">332</a>
<a href="#L333" id="L333">333</a>
<a href="#L334" id="L334">334</a>
<a href="#L335" id="L335">335</a>
<a href="#L336" id="L336">336</a>
<a href="#L337" id="L337">337</a>
<a href="#L338" id="L338">338</a>
<a href="#L339" id="L339">339</a>
<a href="#L340" id="L340">340</a>
<a href="#L341" id="L341">341</a>
<a href="#L342" id="L342">342</a>
<a href="#L343" id="L343">343</a>
<a href="#L344" id="L344">344</a>
<a href="#L345" id="L345">345</a>
<a href="#L346" id="L346">346</a>
<a href="#L347" id="L347">347</a>
<a href="#L348" id="L348">348</a>
<a href="#L349" id="L349">349</a>
<a href="#L350" id="L350">350</a>
<a href="#L351" id="L351">351</a>
<a href="#L352" id="L352">352</a>
<a href="#L353" id="L353">353</a>
<a href="#L354" id="L354">354</a>
<a href="#L355" id="L355">355</a>
<a href="#L356" id="L356">356</a>
<a href="#L357" id="L357">357</a>
<a href="#L358" id="L358">358</a>
<a href="#L359" id="L359">359</a>
<a href="#L360" id="L360">360</a>
<a href="#L361" id="L361">361</a>
<a href="#L362" id="L362">362</a>
<a href="#L363" id="L363">363</a>
<a href="#L364" id="L364">364</a>
<a href="#L365" id="L365">365</a>
<a href="#L366" id="L366">366</a>
<a href="#L367" id="L367">367</a>
<a href="#L368" id="L368">368</a>
<a href="#L369" id="L369">369</a>
<a href="#L370" id="L370">370</a>
<a href="#L371" id="L371">371</a>
<a href="#L372" id="L372">372</a>
<a href="#L373" id="L373">373</a>
<a href="#L374" id="L374">374</a>
<a href="#L375" id="L375">375</a>
<a href="#L376" id="L376">376</a>
<a href="#L377" id="L377">377</a>
<a href="#L378" id="L378">378</a>
<a href="#L379" id="L379">379</a>
<a href="#L380" id="L380">380</a>
<a href="#L381" id="L381">381</a>
<a href="#L382" id="L382">382</a>
<a href="#L383" id="L383">383</a>
<a href="#L384" id="L384">384</a>
<a href="#L385" id="L385">385</a>
<a href="#L386" id="L386">386</a>
<a href="#L387" id="L387">387</a>
<a href="#L388" id="L388">388</a>
<a href="#L389" id="L389">389</a>
<a href="#L390" id="L390">390</a>
<a href="#L391" id="L391">391</a>
<a href="#L392" id="L392">392</a>
<a href="#L393" id="L393">393</a>
<a href="#L394" id="L394">394</a>
<a href="#L395" id="L395">395</a>
<a href="#L396" id="L396">396</a>
<a href="#L397" id="L397">397</a>
<a href="#L398" id="L398">398</a>
<a href="#L399" id="L399">399</a>
<a href="#L400" id="L400">400</a>
<a href="#L401" id="L401">401</a>
<a href="#L402" id="L402">402</a>
<a href="#L403" id="L403">403</a>
<a href="#L404" id="L404">404</a>
<a href="#L405" id="L405">405</a>
<a href="#L406" id="L406">406</a>
<a href="#L407" id="L407">407</a>
<a href="#L408" id="L408">408</a>
<a href="#L409" id="L409">409</a>
<a href="#L410" id="L410">410</a>
<a href="#L411" id="L411">411</a>
<a href="#L412" id="L412">412</a>
<a href="#L413" id="L413">413</a>
<a href="#L414" id="L414">414</a>
<a href="#L415" id="L415">415</a>
<a href="#L416" id="L416">416</a>
<a href="#L417" id="L417">417</a>
<a href="#L418" id="L418">418</a>
<a href="#L419" id="L419">419</a>
<a href="#L420" id="L420">420</a>
<a href="#L421" id="L421">421</a>
<a href="#L422" id="L422">422</a>
<a href="#L423" id="L423">423</a>
<a href="#L424" id="L424">424</a>
<a href="#L425" id="L425">425</a>
<a href="#L426" id="L426">426</a>
<a href="#L427" id="L427">427</a>
<a href="#L428" id="L428">428</a>
<a href="#L429" id="L429">429</a>
<a href="#L430" id="L430">430</a>
<a href="#L431" id="L431">431</a>
<a href="#L432" id="L432">432</a>
<a href="#L433" id="L433">433</a>
<a href="#L434" id="L434">434</a>
<a href="#L435" id="L435">435</a>
<a href="#L436" id="L436">436</a>
<a href="#L437" id="L437">437</a>
<a href="#L438" id="L438">438</a>
<a href="#L439" id="L439">439</a>
<a href="#L440" id="L440">440</a>
<a href="#L441" id="L441">441</a>
<a href="#L442" id="L442">442</a>
<a href="#L443" id="L443">443</a>
<a href="#L444" id="L444">444</a>
<a href="#L445" id="L445">445</a>
<a href="#L446" id="L446">446</a>
<a href="#L447" id="L447">447</a>
<a href="#L448" id="L448">448</a>
<a href="#L449" id="L449">449</a>
<a href="#L450" id="L450">450</a>
<a href="#L451" id="L451">451</a>
<a href="#L452" id="L452">452</a>
<a href="#L453" id="L453">453</a>
<a href="#L454" id="L454">454</a>
<a href="#L455" id="L455">455</a>
<a href="#L456" id="L456">456</a>
<a href="#L457" id="L457">457</a>
<a href="#L458" id="L458">458</a>
<a href="#L459" id="L459">459</a>
<a href="#L460" id="L460">460</a>
<a href="#L461" id="L461">461</a>
<a href="#L462" id="L462">462</a>
<a href="#L463" id="L463">463</a>
<a href="#L464" id="L464">464</a>
<a href="#L465" id="L465">465</a>
<a href="#L466" id="L466">466</a>
<a href="#L467" id="L467">467</a>
<a href="#L468" id="L468">468</a>
<a href="#L469" id="L469">469</a>
<a href="#L470" id="L470">470</a>
<a href="#L471" id="L471">471</a>
<a href="#L472" id="L472">472</a>
<a href="#L473" id="L473">473</a>
<a href="#L474" id="L474">474</a>
<a href="#L475" id="L475">475</a>
<a href="#L476" id="L476">476</a>
<a href="#L477" id="L477">477</a>
<a href="#L478" id="L478">478</a>
<a href="#L479" id="L479">479</a>
<a href="#L480" id="L480">480</a>
<a href="#L481" id="L481">481</a>
<a href="#L482" id="L482">482</a>
<a href="#L483" id="L483">483</a>
<a href="#L484" id="L484">484</a>
<a href="#L485" id="L485">485</a>
<a href="#L486" id="L486">486</a>
<a href="#L487" id="L487">487</a>
<a href="#L488" id="L488">488</a>
<a href="#L489" id="L489">489</a>
<a href="#L490" id="L490">490</a>
<a href="#L491" id="L491">491</a>
<a href="#L492" id="L492">492</a>
<a href="#L493" id="L493">493</a>
<a href="#L494" id="L494">494</a>
<a href="#L495" id="L495">495</a>
<a href="#L496" id="L496">496</a>
<a href="#L497" id="L497">497</a>
<a href="#L498" id="L498">498</a>
<a href="#L499" id="L499">499</a>
<a href="#L500" id="L500">500</a>
<a href="#L501" id="L501">501</a>
<a href="#L502" id="L502">502</a>
<a href="#L503" id="L503">503</a>
<a href="#L504" id="L504">504</a>
<a href="#L505" id="L505">505</a>
<a href="#L506" id="L506">506</a>
<a href="#L507" id="L507">507</a>
<a href="#L508" id="L508">508</a>
<a href="#L509" id="L509">509</a>
<a href="#L510" id="L510">510</a>
<a href="#L511" id="L511">511</a>
<a href="#L512" id="L512">512</a>
<a href="#L513" id="L513">513</a>
<a href="#L514" id="L514">514</a>
<a href="#L515" id="L515">515</a>
<a href="#L516" id="L516">516</a>
<a href="#L517" id="L517">517</a>
<a href="#L518" id="L518">518</a>
<a href="#L519" id="L519">519</a>
<a href="#L520" id="L520">520</a>
<a href="#L521" id="L521">521</a>
<a href="#L522" id="L522">522</a>
<a href="#L523" id="L523">523</a>
<a href="#L524" id="L524">524</a>
<a href="#L525" id="L525">525</a>
<a href="#L526" id="L526">526</a>
<a href="#L527" id="L527">527</a>
<a href="#L528" id="L528">528</a>
<a href="#L529" id="L529">529</a>
<a href="#L530" id="L530">530</a>
<a href="#L531" id="L531">531</a>
<a href="#L532" id="L532">532</a>
<a href="#L533" id="L533">533</a>
<a href="#L534" id="L534">534</a>
<a href="#L535" id="L535">535</a>
<a href="#L536" id="L536">536</a>
<a href="#L537" id="L537">537</a>
<a href="#L538" id="L538">538</a>
<a href="#L539" id="L539">539</a>
<a href="#L540" id="L540">540</a>
<a href="#L541" id="L541">541</a>
<a href="#L542" id="L542">542</a>
<a href="#L543" id="L543">543</a>
<a href="#L544" id="L544">544</a>
<a href="#L545" id="L545">545</a>
<a href="#L546" id="L546">546</a>
<a href="#L547" id="L547">547</a>
<a href="#L548" id="L548">548</a>
<a href="#L549" id="L549">549</a>
<a href="#L550" id="L550">550</a>
<a href="#L551" id="L551">551</a>
<a href="#L552" id="L552">552</a>
<a href="#L553" id="L553">553</a>
<a href="#L554" id="L554">554</a>
<a href="#L555" id="L555">555</a>
<a href="#L556" id="L556">556</a>
<a href="#L557" id="L557">557</a>
<a href="#L558" id="L558">558</a>
<a href="#L559" id="L559">559</a>
<a href="#L560" id="L560">560</a>
<a href="#L561" id="L561">561</a>
<a href="#L562" id="L562">562</a>
<a href="#L563" id="L563">563</a>
<a href="#L564" id="L564">564</a>
<a href="#L565" id="L565">565</a>
<a href="#L566" id="L566">566</a>
<a href="#L567" id="L567">567</a>
<a href="#L568" id="L568">568</a>
<a href="#L569" id="L569">569</a>
<a href="#L570" id="L570">570</a>
<a href="#L571" id="L571">571</a>
<a href="#L572" id="L572">572</a>
<a href="#L573" id="L573">573</a>
<a href="#L574" id="L574">574</a>
<a href="#L575" id="L575">575</a>
<a href="#L576" id="L576">576</a>
<a href="#L577" id="L577">577</a>
<a href="#L578" id="L578">578</a>
<a href="#L579" id="L579">579</a>
<a href="#L580" id="L580">580</a>
<a href="#L581" id="L581">581</a>
<a href="#L582" id="L582">582</a>
<a href="#L583" id="L583">583</a>
<a href="#L584" id="L584">584</a>
<a href="#L585" id="L585">585</a>
<a href="#L586" id="L586">586</a>
<a href="#L587" id="L587">587</a>
<a href="#L588" id="L588">588</a>
<a href="#L589" id="L589">589</a>
<a href="#L590" id="L590">590</a>
<a href="#L591" id="L591">591</a>
<a href="#L592" id="L592">592</a>
<a href="#L593" id="L593">593</a>
<a href="#L594" id="L594">594</a>
<a href="#L595" id="L595">595</a>
<a href="#L596" id="L596">596</a>
<a href="#L597" id="L597">597</a>
<a href="#L598" id="L598">598</a>
<a href="#L599" id="L599">599</a>
<a href="#L600" id="L600">600</a>
<a href="#L601" id="L601">601</a>
<a href="#L602" id="L602">602</a>
<a href="#L603" id="L603">603</a>
<a href="#L604" id="L604">604</a>
<a href="#L605" id="L605">605</a>
<a href="#L606" id="L606">606</a>
<a href="#L607" id="L607">607</a>
<a href="#L608" id="L608">608</a>
<a href="#L609" id="L609">609</a>
<a href="#L610" id="L610">610</a>
<a href="#L611" id="L611">611</a>
<a href="#L612" id="L612">612</a>
<a href="#L613" id="L613">613</a>
<a href="#L614" id="L614">614</a>
<a href="#L615" id="L615">615</a>
<a href="#L616" id="L616">616</a>
<a href="#L617" id="L617">617</a>
<a href="#L618" id="L618">618</a>
<a href="#L619" id="L619">619</a>
<a href="#L620" id="L620">620</a>
<a href="#L621" id="L621">621</a>
<a href="#L622" id="L622">622</a>
<a href="#L623" id="L623">623</a>
<a href="#L624" id="L624">624</a>
<a href="#L625" id="L625">625</a>
<a href="#L626" id="L626">626</a>
<a href="#L627" id="L627">627</a>
<a href="#L628" id="L628">628</a>
<a href="#L629" id="L629">629</a>
<a href="#L630" id="L630">630</a>
<a href="#L631" id="L631">631</a>
<a href="#L632" id="L632">632</a>
<a href="#L633" id="L633">633</a>
<a href="#L634" id="L634">634</a>
<a href="#L635" id="L635">635</a>
<a href="#L636" id="L636">636</a>
<a href="#L637" id="L637">637</a>
<a href="#L638" id="L638">638</a>
<a href="#L639" id="L639">639</a>
<a href="#L640" id="L640">640</a>
<a href="#L641" id="L641">641</a>
<a href="#L642" id="L642">642</a>
<a href="#L643" id="L643">643</a>
<a href="#L644" id="L644">644</a>
<a href="#L645" id="L645">645</a>
<a href="#L646" id="L646">646</a>
<a href="#L647" id="L647">647</a>
<a href="#L648" id="L648">648</a>
<a href="#L649" id="L649">649</a>
<a href="#L650" id="L650">650</a>
<a href="#L651" id="L651">651</a>
<a href="#L652" id="L652">652</a>
<a href="#L653" id="L653">653</a>
<a href="#L654" id="L654">654</a>
<a href="#L655" id="L655">655</a>
<a href="#L656" id="L656">656</a>
<a href="#L657" id="L657">657</a>
<a href="#L658" id="L658">658</a>
<a href="#L659" id="L659">659</a>
<a href="#L660" id="L660">660</a>
<a href="#L661" id="L661">661</a>
<a href="#L662" id="L662">662</a>
<a href="#L663" id="L663">663</a>
<a href="#L664" id="L664">664</a>
<a href="#L665" id="L665">665</a>
<a href="#L666" id="L666">666</a>
<a href="#L667" id="L667">667</a>
<a href="#L668" id="L668">668</a>
<a href="#L669" id="L669">669</a>
<a href="#L670" id="L670">670</a>
<a href="#L671" id="L671">671</a>
<a href="#L672" id="L672">672</a>
<a href="#L673" id="L673">673</a>
<a href="#L674" id="L674">674</a>
<a href="#L675" id="L675">675</a>
<a href="#L676" id="L676">676</a>
<a href="#L677" id="L677">677</a>
<a href="#L678" id="L678">678</a>
<a href="#L679" id="L679">679</a>
<a href="#L680" id="L680">680</a>
<a href="#L681" id="L681">681</a>
<a href="#L682" id="L682">682</a>
<a href="#L683" id="L683">683</a>
<a href="#L684" id="L684">684</a>
<a href="#L685" id="L685">685</a>
<a href="#L686" id="L686">686</a>
<a href="#L687" id="L687">687</a>
<a href="#L688" id="L688">688</a>
<a href="#L689" id="L689">689</a>
<a href="#L690" id="L690">690</a>
<a href="#L691" id="L691">691</a>
<a href="#L692" id="L692">692</a>
<a href="#L693" id="L693">693</a>
<a href="#L694" id="L694">694</a>
<a href="#L695" id="L695">695</a>
<a href="#L696" id="L696">696</a>
<a href="#L697" id="L697">697</a>
<a href="#L698" id="L698">698</a>
<a href="#L699" id="L699">699</a>
<a href="#L700" id="L700">700</a>
<a href="#L701" id="L701">701</a>
<a href="#L702" id="L702">702</a>
<a href="#L703" id="L703">703</a>
<a href="#L704" id="L704">704</a>
<a href="#L705" id="L705">705</a>
<a href="#L706" id="L706">706</a>
<a href="#L707" id="L707">707</a>
<a href="#L708" id="L708">708</a>
<a href="#L709" id="L709">709</a>
<a href="#L710" id="L710">710</a>
<a href="#L711" id="L711">711</a>
<a href="#L712" id="L712">712</a>
<a href="#L713" id="L713">713</a>
<a href="#L714" id="L714">714</a>
<a href="#L715" id="L715">715</a>
<a href="#L716" id="L716">716</a>
<a href="#L717" id="L717">717</a>
<a href="#L718" id="L718">718</a>
<a href="#L719" id="L719">719</a>
<a href="#L720" id="L720">720</a>
<a href="#L721" id="L721">721</a>
<a href="#L722" id="L722">722</a>
<a href="#L723" id="L723">723</a>
<a href="#L724" id="L724">724</a>
<a href="#L725" id="L725">725</a>
<a href="#L726" id="L726">726</a>
<a href="#L727" id="L727">727</a>
<a href="#L728" id="L728">728</a>
<a href="#L729" id="L729">729</a>
<a href="#L730" id="L730">730</a>
<a href="#L731" id="L731">731</a>
<a href="#L732" id="L732">732</a>
<a href="#L733" id="L733">733</a>
<a href="#L734" id="L734">734</a>
<a href="#L735" id="L735">735</a>
<a href="#L736" id="L736">736</a>
<a href="#L737" id="L737">737</a>
<a href="#L738" id="L738">738</a></pre>
<div class="highlight"><pre><span></span><span class="c1"># Pure</span>
<span class="c1"># by Sindre Sorhus</span>
<span class="c1"># https://github.com/sindresorhus/pure</span>
<span class="c1"># MIT License</span>

<span class="c1"># For my own and others sanity</span>
<span class="c1"># git:</span>
<span class="c1"># %b =&gt; current branch</span>
<span class="c1"># %a =&gt; current action (rebase/merge)</span>
<span class="c1"># prompt:</span>
<span class="c1"># %F =&gt; color dict</span>
<span class="c1"># %f =&gt; reset color</span>
<span class="c1"># %~ =&gt; current path</span>
<span class="c1"># %* =&gt; time</span>
<span class="c1"># %n =&gt; username</span>
<span class="c1"># %m =&gt; shortname host</span>
<span class="c1"># %(?..) =&gt; prompt conditional - %(condition.true.false)</span>
<span class="c1"># terminal codes:</span>
<span class="c1"># \e7   =&gt; save cursor position</span>
<span class="c1"># \e[2A =&gt; move cursor 2 lines up</span>
<span class="c1"># \e[1G =&gt; go to position 1 in terminal</span>
<span class="c1"># \e8   =&gt; restore cursor position</span>
<span class="c1"># \e[K  =&gt; clears everything after the cursor on the current line</span>
<span class="c1"># \e[2K =&gt; clear everything on the current line</span>


<span class="c1"># Turns seconds into human readable time.</span>
<span class="c1"># 165392 =&gt; 1d 21h 56m 32s</span>
<span class="c1"># https://github.com/sindresorhus/pretty-time-zsh</span>
prompt_pure_human_time_to_var<span class="o">()</span> <span class="o">{</span>
	<span class="nb">local</span> human <span class="nv">total_seconds</span><span class="o">=</span><span class="nv">$1</span> <span class="nv">var</span><span class="o">=</span><span class="nv">$2</span>
	<span class="nb">local</span> <span class="nv">days</span><span class="o">=</span><span class="k">$((</span> total_seconds <span class="o">/</span> <span class="m">60</span> <span class="o">/</span> <span class="m">60</span> <span class="o">/</span> <span class="m">24</span> <span class="k">))</span>
	<span class="nb">local</span> <span class="nv">hours</span><span class="o">=</span><span class="k">$((</span> total_seconds <span class="o">/</span> <span class="m">60</span> <span class="o">/</span> <span class="m">60</span> <span class="o">%</span> <span class="m">24</span> <span class="k">))</span>
	<span class="nb">local</span> <span class="nv">minutes</span><span class="o">=</span><span class="k">$((</span> total_seconds <span class="o">/</span> <span class="m">60</span> <span class="o">%</span> <span class="m">60</span> <span class="k">))</span>
	<span class="nb">local</span> <span class="nv">seconds</span><span class="o">=</span><span class="k">$((</span> total_seconds <span class="o">%</span> <span class="m">60</span> <span class="k">))</span>
	<span class="o">((</span> days &gt; <span class="m">0</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">human</span><span class="o">+=</span><span class="s2">"</span><span class="si">${</span><span class="nv">days</span><span class="si">}</span><span class="s2">d "</span>
	<span class="o">((</span> hours &gt; <span class="m">0</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">human</span><span class="o">+=</span><span class="s2">"</span><span class="si">${</span><span class="nv">hours</span><span class="si">}</span><span class="s2">h "</span>
	<span class="o">((</span> minutes &gt; <span class="m">0</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">human</span><span class="o">+=</span><span class="s2">"</span><span class="si">${</span><span class="nv">minutes</span><span class="si">}</span><span class="s2">m "</span>
	<span class="nv">human</span><span class="o">+=</span><span class="s2">"</span><span class="si">${</span><span class="nv">seconds</span><span class="si">}</span><span class="s2">s"</span>

	<span class="c1"># Store human readable time in a variable as specified by the caller</span>
	<span class="nb">typeset</span> -g <span class="s2">"</span><span class="si">${</span><span class="nv">var</span><span class="si">}</span><span class="s2">"</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="nv">human</span><span class="si">}</span><span class="s2">"</span>
<span class="o">}</span>

<span class="c1"># Stores (into prompt_pure_cmd_exec_time) the execution</span>
<span class="c1"># time of the last command if set threshold was exceeded.</span>
prompt_pure_check_cmd_exec_time<span class="o">()</span> <span class="o">{</span>
	integer elapsed
	<span class="o">((</span> <span class="nv">elapsed</span> <span class="o">=</span> EPOCHSECONDS - <span class="si">${</span><span class="nv">prompt_pure_cmd_timestamp</span><span class="k">:-</span><span class="nv">$EPOCHSECONDS</span><span class="si">}</span> <span class="o">))</span>
	<span class="nb">typeset</span> -g <span class="nv">prompt_pure_cmd_exec_time</span><span class="o">=</span>
	<span class="o">((</span> elapsed &gt; <span class="si">${</span><span class="nv">PURE_CMD_MAX_EXEC_TIME</span><span class="k">:-</span><span class="nv">5</span><span class="si">}</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="o">{</span>
		prompt_pure_human_time_to_var <span class="nv">$elapsed</span> <span class="s2">"prompt_pure_cmd_exec_time"</span>
	<span class="o">}</span>
<span class="o">}</span>

prompt_pure_set_title<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="c1"># Emacs terminal does not support settings the title.</span>
	<span class="o">((</span> <span class="si">${</span><span class="p">+EMACS</span><span class="si">}</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="k">return</span>

	<span class="k">case</span> <span class="nv">$TTY</span> <span class="k">in</span>
		<span class="c1"># Don't set title over serial console.</span>
		/dev/ttyS<span class="o">[</span><span class="m">0</span>-9<span class="o">]</span>*<span class="o">)</span> <span class="k">return</span><span class="p">;;</span>
	<span class="k">esac</span>

	<span class="c1"># Show hostname if connected via SSH.</span>
	<span class="nb">local</span> <span class="nv">hostname</span><span class="o">=</span>
	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$prompt_pure_state</span><span class="o">[</span>username<span class="o">]</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Expand in-place in case ignore-escape is used.</span>
		<span class="nv">hostname</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="p">(%)</span><span class="k">:-</span><span class="p">(%m) </span><span class="si">}</span><span class="s2">"</span>
	<span class="k">fi</span>

	<span class="nb">local</span> -a opts
	<span class="k">case</span> <span class="nv">$1</span> <span class="k">in</span>
		expand-prompt<span class="o">)</span> <span class="nv">opts</span><span class="o">=(</span>-P<span class="o">)</span><span class="p">;;</span>
		ignore-escape<span class="o">)</span> <span class="nv">opts</span><span class="o">=(</span>-r<span class="o">)</span><span class="p">;;</span>
	<span class="k">esac</span>

	<span class="c1"># Set title atomically in one print statement so that it works when XTRACE is enabled.</span>
	print -n <span class="nv">$opts</span> <span class="s1">$'\e]0;'</span><span class="si">${</span><span class="nv">hostname</span><span class="si">}${</span><span class="nv">2</span><span class="si">}</span><span class="s1">$'\a'</span>
<span class="o">}</span>

prompt_pure_preexec<span class="o">()</span> <span class="o">{</span>
	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$prompt_pure_git_fetch_pattern</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Detect when Git is performing pull/fetch, including Git aliases.</span>
		<span class="nb">local</span> -H MATCH MBEGIN MEND match mbegin mend
		<span class="k">if</span> <span class="o">[[</span> <span class="nv">$2</span> <span class="o">=</span>~ <span class="o">(</span>git<span class="p">|</span>hub<span class="o">)</span><span class="se">\ </span><span class="o">(</span>.*<span class="se">\ </span><span class="o">)</span>?<span class="o">(</span><span class="nv">$prompt_pure_git_fetch_pattern</span><span class="o">)(</span><span class="se">\ </span>.*<span class="o">)</span>?$ <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
			<span class="c1"># We must flush the async jobs to cancel our git fetch in order</span>
			<span class="c1"># to avoid conflicts with the user issued pull / fetch.</span>
			async_flush_jobs <span class="s1">'prompt_pure'</span>
		<span class="k">fi</span>
	<span class="k">fi</span>

	<span class="nb">typeset</span> -g <span class="nv">prompt_pure_cmd_timestamp</span><span class="o">=</span><span class="nv">$EPOCHSECONDS</span>

	<span class="c1"># Shows the current directory and executed command in the title while a process is active.</span>
	prompt_pure_set_title <span class="s1">'ignore-escape'</span> <span class="s2">"</span><span class="nv">$PWD</span><span class="s2">:t: </span><span class="nv">$2</span><span class="s2">"</span>

	<span class="c1"># Disallow Python virtualenv from updating the prompt. Set it to 12 if</span>
	<span class="c1"># untouched by the user to indicate that Pure modified it. Here we use</span>
	<span class="c1"># the magic number 12, same as in `psvar`.</span>
	<span class="nb">export</span> <span class="nv">VIRTUAL_ENV_DISABLE_PROMPT</span><span class="o">=</span><span class="si">${</span><span class="nv">VIRTUAL_ENV_DISABLE_PROMPT</span><span class="k">:-</span><span class="nv">12</span><span class="si">}</span>
<span class="o">}</span>

<span class="c1"># Change the colors if their value are different from the current ones.</span>
prompt_pure_set_colors<span class="o">()</span> <span class="o">{</span>
	<span class="nb">local</span> color_temp key value
	<span class="k">for</span> key value <span class="k">in</span> <span class="si">${</span><span class="p">(kv)prompt_pure_colors</span><span class="si">}</span><span class="p">;</span> <span class="k">do</span>
		zstyle -t <span class="s2">":prompt:pure:</span><span class="nv">$key</span><span class="s2">"</span> color <span class="s2">"</span><span class="nv">$value</span><span class="s2">"</span>
		<span class="k">case</span> <span class="nv">$?</span> <span class="k">in</span>
			<span class="m">1</span><span class="o">)</span> <span class="c1"># The current style is different from the one from zstyle.</span>
				zstyle -s <span class="s2">":prompt:pure:</span><span class="nv">$key</span><span class="s2">"</span> color color_temp
				prompt_pure_colors<span class="o">[</span><span class="nv">$key</span><span class="o">]=</span><span class="nv">$color_temp</span> <span class="p">;;</span>
			<span class="m">2</span><span class="o">)</span> <span class="c1"># No style is defined.</span>
				prompt_pure_colors<span class="o">[</span><span class="nv">$key</span><span class="o">]=</span><span class="nv">$prompt_pure_colors_default</span><span class="o">[</span><span class="nv">$key</span><span class="o">]</span> <span class="p">;;</span>
		<span class="k">esac</span>
	<span class="k">done</span>
<span class="o">}</span>

prompt_pure_preprompt_render<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="c1"># Set color for Git branch/dirty status and change color if dirty checking has been delayed.</span>
	<span class="nb">local</span> <span class="nv">git_color</span><span class="o">=</span><span class="nv">$prompt_pure_colors</span><span class="o">[</span>git:branch<span class="o">]</span>
	<span class="o">[[</span> -n <span class="si">${</span><span class="nv">prompt_pure_git_last_dirty_check_timestamp</span><span class="p">+x</span><span class="si">}</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="nv">git_color</span><span class="o">=</span><span class="nv">$prompt_pure_colors</span><span class="o">[</span>git:branch:cached<span class="o">]</span>

	<span class="c1"># Initialize the preprompt array.</span>
	<span class="nb">local</span> -a preprompt_parts

	<span class="c1"># Set the path.</span>
	<span class="nv">preprompt_parts</span><span class="o">+=(</span><span class="s1">'%F{${prompt_pure_colors[path]}}%~%f'</span><span class="o">)</span>

	<span class="c1"># Add Git branch and dirty status info.</span>
	<span class="nb">typeset</span> -gA prompt_pure_vcs_info
	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$prompt_pure_vcs_info</span><span class="o">[</span>branch<span class="o">]</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="nv">preprompt_parts</span><span class="o">+=(</span><span class="s2">"%F{</span><span class="nv">$git_color</span><span class="s2">}"</span><span class="s1">'${prompt_pure_vcs_info[branch]}${prompt_pure_git_dirty}%f'</span><span class="o">)</span>
	<span class="k">fi</span>
	<span class="c1"># Git pull/push arrows.</span>
	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$prompt_pure_git_arrows</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="nv">preprompt_parts</span><span class="o">+=(</span><span class="s1">'%F{$prompt_pure_colors[git:arrow]}${prompt_pure_git_arrows}%f'</span><span class="o">)</span>
	<span class="k">fi</span>

	<span class="c1"># Username and machine, if applicable.</span>
	<span class="o">[[</span> -n <span class="nv">$prompt_pure_state</span><span class="o">[</span>username<span class="o">]</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="nv">preprompt_parts</span><span class="o">+=(</span><span class="nv">$prompt_pure_state</span><span class="o">[</span>username<span class="o">])</span>
	<span class="c1"># Execution time.</span>
	<span class="o">[[</span> -n <span class="nv">$prompt_pure_cmd_exec_time</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="nv">preprompt_parts</span><span class="o">+=(</span><span class="s1">'%F{$prompt_pure_colors[execution_time]}${prompt_pure_cmd_exec_time}%f'</span><span class="o">)</span>

	<span class="nb">local</span> <span class="nv">cleaned_ps1</span><span class="o">=</span><span class="nv">$PROMPT</span>
	<span class="nb">local</span> -H MATCH MBEGIN MEND
	<span class="k">if</span> <span class="o">[[</span> <span class="nv">$PROMPT</span> <span class="o">=</span> *<span class="nv">$prompt_newline</span>* <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Remove everything from the prompt until the newline. This</span>
		<span class="c1"># removes the preprompt and only the original PROMPT remains.</span>
		<span class="nv">cleaned_ps1</span><span class="o">=</span><span class="si">${</span><span class="nv">PROMPT</span><span class="p">##*</span><span class="si">${</span><span class="nv">prompt_newline</span><span class="si">}}</span>
	<span class="k">fi</span>
	<span class="nb">unset</span> MATCH MBEGIN MEND

	<span class="c1"># Construct the new prompt with a clean preprompt.</span>
	<span class="nb">local</span> -ah ps1
	<span class="nv">ps1</span><span class="o">=(</span>
		<span class="si">${</span><span class="p">(j. .)preprompt_parts</span><span class="si">}</span>  <span class="c1"># Join parts, space separated.</span>
		<span class="nv">$prompt_newline</span>           <span class="c1"># Separate preprompt and prompt.</span>
		<span class="nv">$cleaned_ps1</span>
	<span class="o">)</span>

	<span class="nv">PROMPT</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="p">(j..)ps1</span><span class="si">}</span><span class="s2">"</span>

	<span class="c1"># Expand the prompt for future comparision.</span>
	<span class="nb">local</span> expanded_prompt
	<span class="nv">expanded_prompt</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="p">(S%%)PROMPT</span><span class="si">}</span><span class="s2">"</span>

	<span class="k">if</span> <span class="o">[[</span> <span class="nv">$1</span> <span class="o">==</span> precmd <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Initial newline, for spaciousness.</span>
		print
	<span class="k">elif</span> <span class="o">[[</span> <span class="nv">$prompt_pure_last_prompt</span> !<span class="o">=</span> <span class="nv">$expanded_prompt</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Redraw the prompt.</span>
		prompt_pure_reset_prompt
	<span class="k">fi</span>

	<span class="nb">typeset</span> -g <span class="nv">prompt_pure_last_prompt</span><span class="o">=</span><span class="nv">$expanded_prompt</span>
<span class="o">}</span>

prompt_pure_precmd<span class="o">()</span> <span class="o">{</span>
	<span class="c1"># Check execution time and store it in a variable.</span>
	prompt_pure_check_cmd_exec_time
	<span class="nb">unset</span> prompt_pure_cmd_timestamp

	<span class="c1"># Shows the full path in the title.</span>
	prompt_pure_set_title <span class="s1">'expand-prompt'</span> <span class="s1">'%~'</span>

	<span class="c1"># Modify the colors if some have changed..</span>
	prompt_pure_set_colors

	<span class="c1"># Perform async Git dirty check and fetch.</span>
	prompt_pure_async_tasks

	<span class="c1"># Check if we should display the virtual env. We use a sufficiently high</span>
	<span class="c1"># index of psvar (12) here to avoid collisions with user defined entries.</span>
	psvar<span class="o">[</span><span class="m">12</span><span class="o">]=</span>
	<span class="c1"># Check if a Conda environment is active and display its name.</span>
	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$CONDA_DEFAULT_ENV</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		psvar<span class="o">[</span><span class="m">12</span><span class="o">]=</span><span class="s2">"</span><span class="si">${</span><span class="nv">CONDA_DEFAULT_ENV</span><span class="p">//[</span><span class="s1">$'\t\r\n'</span><span class="p">]</span><span class="si">}</span><span class="s2">"</span>
	<span class="k">fi</span>
	<span class="c1"># When VIRTUAL_ENV_DISABLE_PROMPT is empty, it was unset by the user and</span>
	<span class="c1"># Pure should take back control.</span>
	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$VIRTUAL_ENV</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="o">[[</span> -z <span class="nv">$VIRTUAL_ENV_DISABLE_PROMPT</span> <span class="o">||</span> <span class="nv">$VIRTUAL_ENV_DISABLE_PROMPT</span> <span class="o">=</span> <span class="m">12</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		psvar<span class="o">[</span><span class="m">12</span><span class="o">]=</span><span class="s2">"</span><span class="si">${</span><span class="nv">VIRTUAL_ENV</span><span class="p">:</span><span class="nv">t</span><span class="si">}</span><span class="s2">"</span>
		<span class="nb">export</span> <span class="nv">VIRTUAL_ENV_DISABLE_PROMPT</span><span class="o">=</span><span class="m">12</span>
	<span class="k">fi</span>

	<span class="c1"># Make sure VIM prompt is reset.</span>
	prompt_pure_reset_prompt_symbol

	<span class="c1"># Print the preprompt.</span>
	prompt_pure_preprompt_render <span class="s2">"precmd"</span>

	<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$ZSH_THEME</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		print <span class="s2">"WARNING: Oh My Zsh themes are enabled (ZSH_THEME='</span><span class="si">${</span><span class="nv">ZSH_THEME</span><span class="si">}</span><span class="s2">'). Pure might not be working correctly."</span>
		print <span class="s2">"For more information, see: https://github.com/sindresorhus/pure#oh-my-zsh"</span>
		<span class="nb">unset</span> ZSH_THEME  <span class="c1"># Only show this warning once.</span>
	<span class="k">fi</span>
<span class="o">}</span>

prompt_pure_async_git_aliases<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	<span class="nb">local</span> -a gitalias pullalias

	<span class="c1"># List all aliases and split on newline.</span>
	<span class="nv">gitalias</span><span class="o">=(</span><span class="si">${</span><span class="p">(@f)</span><span class="s2">"</span><span class="k">$(</span><span class="nb">command</span> git config --get-regexp <span class="s2">"^alias\."</span><span class="k">)</span><span class="s2">"</span><span class="si">}</span><span class="o">)</span>
	<span class="k">for</span> line <span class="k">in</span> <span class="nv">$gitalias</span><span class="p">;</span> <span class="k">do</span>
		<span class="nv">parts</span><span class="o">=(</span><span class="si">${</span><span class="p">(@)=line</span><span class="si">}</span><span class="o">)</span>           <span class="c1"># Split line on spaces.</span>
		<span class="nv">aliasname</span><span class="o">=</span><span class="si">${</span><span class="nv">parts</span><span class="p">[1]#alias.</span><span class="si">}</span>  <span class="c1"># Grab the name (alias.[name]).</span>
		<span class="nb">shift</span> parts                   <span class="c1"># Remove `aliasname`</span>

		<span class="c1"># Check alias for pull or fetch. Must be exact match.</span>
		<span class="k">if</span> <span class="o">[[</span> <span class="nv">$parts</span> <span class="o">=</span>~ ^<span class="o">(</span>.*<span class="se">\ </span><span class="o">)</span>?<span class="o">(</span>pull<span class="p">|</span>fetch<span class="o">)(</span><span class="se">\ </span>.*<span class="o">)</span>?$ <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
			<span class="nv">pullalias</span><span class="o">+=(</span><span class="nv">$aliasname</span><span class="o">)</span>
		<span class="k">fi</span>
	<span class="k">done</span>

	print -- <span class="si">${</span><span class="p">(j:|:)pullalias</span><span class="si">}</span>  <span class="c1"># Join on pipe, for use in regex.</span>
<span class="o">}</span>

prompt_pure_async_vcs_info<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="c1"># Configure `vcs_info` inside an async task. This frees up `vcs_info`</span>
	<span class="c1"># to be used or configured as the user pleases.</span>
	zstyle <span class="s1">':vcs_info:*'</span> <span class="nb">enable</span> git
	zstyle <span class="s1">':vcs_info:*'</span> use-simple <span class="nb">true</span>
	<span class="c1"># Only export two message variables from `vcs_info`.</span>
	zstyle <span class="s1">':vcs_info:*'</span> max-exports <span class="m">2</span>
	<span class="c1"># Export branch (%b) and Git toplevel (%R).</span>
	zstyle <span class="s1">':vcs_info:git*'</span> formats <span class="s1">'%b'</span> <span class="s1">'%R'</span>
	zstyle <span class="s1">':vcs_info:git*'</span> actionformats <span class="s1">'%b|%a'</span> <span class="s1">'%R'</span>

	vcs_info

	<span class="nb">local</span> -A info
	info<span class="o">[</span>pwd<span class="o">]=</span><span class="nv">$PWD</span>
	info<span class="o">[</span>top<span class="o">]=</span><span class="nv">$vcs_info_msg_1_</span>
	info<span class="o">[</span>branch<span class="o">]=</span><span class="nv">$vcs_info_msg_0_</span>

	print -r - <span class="si">${</span><span class="p">(@kvq)info</span><span class="si">}</span>
<span class="o">}</span>

<span class="c1"># Fastest possible way to check if a Git repo is dirty.</span>
prompt_pure_async_git_dirty<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	<span class="nb">local</span> <span class="nv">untracked_dirty</span><span class="o">=</span><span class="nv">$1</span>

	<span class="k">if</span> <span class="o">[[</span> <span class="nv">$untracked_dirty</span> <span class="o">=</span> <span class="m">0</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="nb">command</span> git diff --no-ext-diff --quiet --exit-code
	<span class="k">else</span>
		<span class="nb">test</span> -z <span class="s2">"</span><span class="k">$(</span><span class="nb">command</span> git status --porcelain --ignore-submodules -unormal<span class="k">)</span><span class="s2">"</span>
	<span class="k">fi</span>

	<span class="k">return</span> <span class="nv">$?</span>
<span class="o">}</span>

prompt_pure_async_git_fetch<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="c1"># Sets `GIT_TERMINAL_PROMPT=0` to disable authentication prompt for Git fetch (Git 2.3+).</span>
	<span class="nb">export</span> <span class="nv">GIT_TERMINAL_PROMPT</span><span class="o">=</span><span class="m">0</span>
	<span class="c1"># Set SSH `BachMode` to disable all interactive SSH password prompting.</span>
	<span class="nb">export</span> <span class="nv">GIT_SSH_COMMAND</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="nv">GIT_SSH_COMMAND</span><span class="k">:-</span><span class="s2">"ssh"</span><span class="si">}</span><span class="s2"> -o BatchMode=yes"</span>

	<span class="c1"># Default return code, which indicates Git fetch failure.</span>
	<span class="nb">local</span> <span class="nv">fail_code</span><span class="o">=</span><span class="m">99</span>

	<span class="c1"># Guard against all forms of password prompts. By setting the shell into</span>
	<span class="c1"># MONITOR mode we can notice when a child process prompts for user input</span>
	<span class="c1"># because it will be suspended. Since we are inside an async worker, we</span>
	<span class="c1"># have no way of transmitting the password and the only option is to</span>
	<span class="c1"># kill it. If we don't do it this way, the process will corrupt with the</span>
	<span class="c1"># async worker.</span>
	setopt localtraps monitor

	<span class="c1"># Make sure local HUP trap is unset to allow for signal propagation when</span>
	<span class="c1"># the async worker is flushed.</span>
	<span class="nb">trap</span> - HUP

	<span class="nb">trap</span> <span class="s1">'</span>
<span class="s1">		# Unset trap to prevent infinite loop</span>
<span class="s1">		trap - CHLD</span>
<span class="s1">		if [[ $jobstates = suspended* ]]; then</span>
<span class="s1">			# Set fail code to password prompt and kill the fetch.</span>
<span class="s1">			fail_code=98</span>
<span class="s1">			kill %%</span>
<span class="s1">		fi</span>
<span class="s1">	'</span> CHLD

	<span class="nb">command</span> git -c gc.auto<span class="o">=</span><span class="m">0</span> fetch &gt;/dev/null <span class="p">&amp;</span>
	<span class="nb">wait</span> <span class="nv">$!</span> <span class="o">||</span> <span class="k">return</span> <span class="nv">$fail_code</span>

	unsetopt monitor

	<span class="c1"># Check arrow status after a successful `git fetch`.</span>
	prompt_pure_async_git_arrows
<span class="o">}</span>

prompt_pure_async_git_arrows<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	<span class="nb">command</span> git rev-list --left-right --count HEAD...@<span class="s1">'{u}'</span>
<span class="o">}</span>

prompt_pure_async_tasks<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="c1"># Initialize the async worker.</span>
	<span class="o">((</span>!<span class="si">${</span><span class="nv">prompt_pure_async_init</span><span class="k">:-</span><span class="nv">0</span><span class="si">}</span><span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="o">{</span>
		async_start_worker <span class="s2">"prompt_pure"</span> -u -n
		async_register_callback <span class="s2">"prompt_pure"</span> prompt_pure_async_callback
		<span class="nb">typeset</span> -g <span class="nv">prompt_pure_async_init</span><span class="o">=</span><span class="m">1</span>
	<span class="o">}</span>

	<span class="c1"># Update the current working directory of the async worker.</span>
	async_worker_eval <span class="s2">"prompt_pure"</span> <span class="nb">builtin</span> <span class="nb">cd</span> -q <span class="nv">$PWD</span>

	<span class="nb">typeset</span> -gA prompt_pure_vcs_info

	<span class="nb">local</span> -H MATCH MBEGIN MEND
	<span class="k">if</span> <span class="o">[[</span> <span class="nv">$PWD</span> !<span class="o">=</span> <span class="si">${</span><span class="nv">prompt_pure_vcs_info</span><span class="p">[pwd]</span><span class="si">}</span>* <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Stop any running async jobs.</span>
		async_flush_jobs <span class="s2">"prompt_pure"</span>

		<span class="c1"># Reset Git preprompt variables, switching working tree.</span>
		<span class="nb">unset</span> prompt_pure_git_dirty
		<span class="nb">unset</span> prompt_pure_git_last_dirty_check_timestamp
		<span class="nb">unset</span> prompt_pure_git_arrows
		<span class="nb">unset</span> prompt_pure_git_fetch_pattern
		prompt_pure_vcs_info<span class="o">[</span>branch<span class="o">]=</span>
		prompt_pure_vcs_info<span class="o">[</span>top<span class="o">]=</span>
	<span class="k">fi</span>
	<span class="nb">unset</span> MATCH MBEGIN MEND

	async_job <span class="s2">"prompt_pure"</span> prompt_pure_async_vcs_info

	<span class="c1"># Only perform tasks inside a Git working tree.</span>
	<span class="o">[[</span> -n <span class="nv">$prompt_pure_vcs_info</span><span class="o">[</span>top<span class="o">]</span> <span class="o">]]</span> <span class="o">||</span> <span class="k">return</span>

	prompt_pure_async_refresh
<span class="o">}</span>

prompt_pure_async_refresh<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="k">if</span> <span class="o">[[</span> -z <span class="nv">$prompt_pure_git_fetch_pattern</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># We set the pattern here to avoid redoing the pattern check until the</span>
		<span class="c1"># working three has changed. Pull and fetch are always valid patterns.</span>
		<span class="nb">typeset</span> -g <span class="nv">prompt_pure_git_fetch_pattern</span><span class="o">=</span><span class="s2">"pull|fetch"</span>
		async_job <span class="s2">"prompt_pure"</span> prompt_pure_async_git_aliases
	<span class="k">fi</span>

	async_job <span class="s2">"prompt_pure"</span> prompt_pure_async_git_arrows

	<span class="c1"># Do not preform `git fetch` if it is disabled or in home folder.</span>
	<span class="k">if</span> <span class="o">((</span> <span class="si">${</span><span class="nv">PURE_GIT_PULL</span><span class="k">:-</span><span class="nv">1</span><span class="si">}</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="o">[[</span> <span class="nv">$prompt_pure_vcs_info</span><span class="o">[</span>top<span class="o">]</span> !<span class="o">=</span> <span class="nv">$HOME</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># Tell the async worker to do a `git fetch`.</span>
		async_job <span class="s2">"prompt_pure"</span> prompt_pure_async_git_fetch
	<span class="k">fi</span>

	<span class="c1"># If dirty checking is sufficiently fast,</span>
	<span class="c1"># tell the worker to check it again, or wait for timeout.</span>
	integer <span class="nv">time_since_last_dirty_check</span><span class="o">=</span><span class="k">$((</span> EPOCHSECONDS <span class="o">-</span> <span class="si">${</span><span class="nv">prompt_pure_git_last_dirty_check_timestamp</span><span class="k">:-</span><span class="nv">0</span><span class="si">}</span> <span class="k">))</span>
	<span class="k">if</span> <span class="o">((</span> time_since_last_dirty_check &gt; <span class="si">${</span><span class="nv">PURE_GIT_DELAY_DIRTY_CHECK</span><span class="k">:-</span><span class="nv">1800</span><span class="si">}</span> <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
		<span class="nb">unset</span> prompt_pure_git_last_dirty_check_timestamp
		<span class="c1"># Check check if there is anything to pull.</span>
		async_job <span class="s2">"prompt_pure"</span> prompt_pure_async_git_dirty <span class="si">${</span><span class="nv">PURE_GIT_UNTRACKED_DIRTY</span><span class="k">:-</span><span class="nv">1</span><span class="si">}</span>
	<span class="k">fi</span>
<span class="o">}</span>

prompt_pure_check_git_arrows<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	<span class="nb">local</span> arrows <span class="nv">left</span><span class="o">=</span><span class="si">${</span><span class="nv">1</span><span class="k">:-</span><span class="nv">0</span><span class="si">}</span> <span class="nv">right</span><span class="o">=</span><span class="si">${</span><span class="nv">2</span><span class="k">:-</span><span class="nv">0</span><span class="si">}</span>

	<span class="o">((</span> right &gt; <span class="m">0</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">arrows</span><span class="o">+=</span><span class="si">${</span><span class="nv">PURE_GIT_DOWN_ARROW</span><span class="k">:-</span><span class="p">⇣</span><span class="si">}</span>
	<span class="o">((</span> left &gt; <span class="m">0</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">arrows</span><span class="o">+=</span><span class="si">${</span><span class="nv">PURE_GIT_UP_ARROW</span><span class="k">:-</span><span class="p">⇡</span><span class="si">}</span>

	<span class="o">[[</span> -n <span class="nv">$arrows</span> <span class="o">]]</span> <span class="o">||</span> <span class="k">return</span>
	<span class="nb">typeset</span> -g <span class="nv">REPLY</span><span class="o">=</span><span class="nv">$arrows</span>
<span class="o">}</span>

prompt_pure_async_callback<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	<span class="nb">local</span> <span class="nv">job</span><span class="o">=</span><span class="nv">$1</span> <span class="nv">code</span><span class="o">=</span><span class="nv">$2</span> <span class="nv">output</span><span class="o">=</span><span class="nv">$3</span> <span class="nv">exec_time</span><span class="o">=</span><span class="nv">$4</span> <span class="nv">next_pending</span><span class="o">=</span><span class="nv">$6</span>
	<span class="nb">local</span> <span class="nv">do_render</span><span class="o">=</span><span class="m">0</span>

	<span class="k">case</span> <span class="nv">$job</span> <span class="k">in</span>
		<span class="se">\[</span>async<span class="o">])</span>
			<span class="c1"># Code is 1 for corrupted worker output and 2 for dead worker.</span>
			<span class="k">if</span> <span class="o">[[</span> <span class="nv">$code</span> -eq <span class="m">2</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
				<span class="c1"># Our worker died unexpectedly.</span>
				<span class="nb">typeset</span> -g <span class="nv">prompt_pure_async_init</span><span class="o">=</span><span class="m">0</span>
			<span class="k">fi</span>
			<span class="p">;;</span>
		prompt_pure_async_vcs_info<span class="o">)</span>
			<span class="nb">local</span> -A info
			<span class="nb">typeset</span> -gA prompt_pure_vcs_info

			<span class="c1"># Parse output (z) and unquote as array (Q@).</span>
			<span class="nv">info</span><span class="o">=(</span><span class="s2">"</span><span class="si">${</span><span class="p">(Q@)</span><span class="si">${</span><span class="p">(z)output</span><span class="si">}}</span><span class="s2">"</span><span class="o">)</span>
			<span class="nb">local</span> -H MATCH MBEGIN MEND
			<span class="k">if</span> <span class="o">[[</span> <span class="nv">$info</span><span class="o">[</span>pwd<span class="o">]</span> !<span class="o">=</span> <span class="nv">$PWD</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
				<span class="c1"># The path has changed since the check started, abort.</span>
				<span class="k">return</span>
			<span class="k">fi</span>
			<span class="c1"># Check if Git top-level has changed.</span>
			<span class="k">if</span> <span class="o">[[</span> <span class="nv">$info</span><span class="o">[</span>top<span class="o">]</span> <span class="o">=</span> <span class="nv">$prompt_pure_vcs_info</span><span class="o">[</span>top<span class="o">]</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
				<span class="c1"># If the stored pwd is part of $PWD, $PWD is shorter and likelier</span>
				<span class="c1"># to be top-level, so we update pwd.</span>
				<span class="k">if</span> <span class="o">[[</span> <span class="nv">$prompt_pure_vcs_info</span><span class="o">[</span>pwd<span class="o">]</span> <span class="o">=</span> <span class="si">${</span><span class="nv">PWD</span><span class="si">}</span>* <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
					prompt_pure_vcs_info<span class="o">[</span>pwd<span class="o">]=</span><span class="nv">$PWD</span>
				<span class="k">fi</span>
			<span class="k">else</span>
				<span class="c1"># Store $PWD to detect if we (maybe) left the Git path.</span>
				prompt_pure_vcs_info<span class="o">[</span>pwd<span class="o">]=</span><span class="nv">$PWD</span>
			<span class="k">fi</span>
			<span class="nb">unset</span> MATCH MBEGIN MEND

			<span class="c1"># The update has a Git top-level set, which means we just entered a new</span>
			<span class="c1"># Git directory. Run the async refresh tasks.</span>
			<span class="o">[[</span> -n <span class="nv">$info</span><span class="o">[</span>top<span class="o">]</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="o">[[</span> -z <span class="nv">$prompt_pure_vcs_info</span><span class="o">[</span>top<span class="o">]</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> prompt_pure_async_refresh

			<span class="c1"># Always update branch and top-level.</span>
			prompt_pure_vcs_info<span class="o">[</span>branch<span class="o">]=</span><span class="nv">$info</span><span class="o">[</span>branch<span class="o">]</span>
			prompt_pure_vcs_info<span class="o">[</span>top<span class="o">]=</span><span class="nv">$info</span><span class="o">[</span>top<span class="o">]</span>

			<span class="nv">do_render</span><span class="o">=</span><span class="m">1</span>
			<span class="p">;;</span>
		prompt_pure_async_git_aliases<span class="o">)</span>
			<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$output</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
				<span class="c1"># Append custom Git aliases to the predefined ones.</span>
				<span class="nv">prompt_pure_git_fetch_pattern</span><span class="o">+=</span><span class="s2">"|</span><span class="nv">$output</span><span class="s2">"</span>
			<span class="k">fi</span>
			<span class="p">;;</span>
		prompt_pure_async_git_dirty<span class="o">)</span>
			<span class="nb">local</span> <span class="nv">prev_dirty</span><span class="o">=</span><span class="nv">$prompt_pure_git_dirty</span>
			<span class="k">if</span> <span class="o">((</span> <span class="nv">code</span> <span class="o">==</span> <span class="m">0</span> <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
				<span class="nb">unset</span> prompt_pure_git_dirty
			<span class="k">else</span>
				<span class="nb">typeset</span> -g <span class="nv">prompt_pure_git_dirty</span><span class="o">=</span><span class="s2">"*"</span>
			<span class="k">fi</span>

			<span class="o">[[</span> <span class="nv">$prev_dirty</span> !<span class="o">=</span> <span class="nv">$prompt_pure_git_dirty</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="nv">do_render</span><span class="o">=</span><span class="m">1</span>

			<span class="c1"># When `prompt_pure_git_last_dirty_check_timestamp` is set, the Git info is displayed</span>
			<span class="c1"># in a different color. To distinguish between a "fresh" and a "cached" result, the</span>
			<span class="c1"># preprompt is rendered before setting this variable. Thus, only upon the next</span>
			<span class="c1"># rendering of the preprompt will the result appear in a different color.</span>
			<span class="o">((</span> <span class="nv">$exec_time</span> &gt; <span class="m">5</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">prompt_pure_git_last_dirty_check_timestamp</span><span class="o">=</span><span class="nv">$EPOCHSECONDS</span>
			<span class="p">;;</span>
		prompt_pure_async_git_fetch<span class="p">|</span>prompt_pure_async_git_arrows<span class="o">)</span>
			<span class="c1"># `prompt_pure_async_git_fetch` executes `prompt_pure_async_git_arrows`</span>
			<span class="c1"># after a successful fetch.</span>
			<span class="k">case</span> <span class="nv">$code</span> <span class="k">in</span>
				<span class="m">0</span><span class="o">)</span>
					<span class="nb">local</span> REPLY
					prompt_pure_check_git_arrows <span class="si">${</span><span class="p">(ps:</span><span class="se">\t</span><span class="p">:)output</span><span class="si">}</span>
					<span class="k">if</span> <span class="o">[[</span> <span class="nv">$prompt_pure_git_arrows</span> !<span class="o">=</span> <span class="nv">$REPLY</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
						<span class="nb">typeset</span> -g <span class="nv">prompt_pure_git_arrows</span><span class="o">=</span><span class="nv">$REPLY</span>
						<span class="nv">do_render</span><span class="o">=</span><span class="m">1</span>
					<span class="k">fi</span>
					<span class="p">;;</span>
				<span class="m">99</span><span class="p">|</span><span class="m">98</span><span class="o">)</span>
					<span class="c1"># Git fetch failed.</span>
					<span class="p">;;</span>
				*<span class="o">)</span>
					<span class="c1"># Non-zero exit status from `prompt_pure_async_git_arrows`,</span>
					<span class="c1"># indicating that there is no upstream configured.</span>
					<span class="k">if</span> <span class="o">[[</span> -n <span class="nv">$prompt_pure_git_arrows</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
						<span class="nb">unset</span> prompt_pure_git_arrows
						<span class="nv">do_render</span><span class="o">=</span><span class="m">1</span>
					<span class="k">fi</span>
					<span class="p">;;</span>
			<span class="k">esac</span>
			<span class="p">;;</span>
	<span class="k">esac</span>

	<span class="k">if</span> <span class="o">((</span> next_pending <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
		<span class="o">((</span> do_render <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nb">typeset</span> -g <span class="nv">prompt_pure_async_render_requested</span><span class="o">=</span><span class="m">1</span>
		<span class="k">return</span>
	<span class="k">fi</span>

	<span class="o">[[</span> <span class="si">${</span><span class="nv">prompt_pure_async_render_requested</span><span class="k">:-</span><span class="nv">$do_render</span><span class="si">}</span> <span class="o">=</span> <span class="m">1</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> prompt_pure_preprompt_render
	<span class="nb">unset</span> prompt_pure_async_render_requested
<span class="o">}</span>

prompt_pure_reset_prompt<span class="o">()</span> <span class="o">{</span>
	<span class="k">if</span> <span class="o">[[</span> <span class="nv">$CONTEXT</span> <span class="o">==</span> cont <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># When the context is "cont", PS2 is active and calling</span>
		<span class="c1"># reset-prompt will have no effect on PS1, but it will</span>
		<span class="c1"># reset the execution context (%_) of PS2 which we don't</span>
		<span class="c1"># want. Unfortunately, we can't save the output of "%_"</span>
		<span class="c1"># either because it is only ever rendered as part of the</span>
		<span class="c1"># prompt, expanding in-place won't work.</span>
		<span class="k">return</span>
	<span class="k">fi</span>

	zle <span class="o">&amp;&amp;</span> zle .reset-prompt
<span class="o">}</span>

prompt_pure_reset_prompt_symbol<span class="o">()</span> <span class="o">{</span>
	prompt_pure_state<span class="o">[</span>prompt<span class="o">]=</span><span class="si">${</span><span class="nv">PURE_PROMPT_SYMBOL</span><span class="k">:-</span><span class="p">❯</span><span class="si">}</span>
<span class="o">}</span>

prompt_pure_update_vim_prompt_widget<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	prompt_pure_state<span class="o">[</span>prompt<span class="o">]=</span><span class="si">${${</span><span class="nv">KEYMAP</span><span class="p">/vicmd/</span><span class="si">${</span><span class="nv">PURE_PROMPT_VICMD_SYMBOL</span><span class="k">:-</span><span class="p">❮</span><span class="si">}}</span><span class="p">/(main|viins)/</span><span class="si">${</span><span class="nv">PURE_PROMPT_SYMBOL</span><span class="k">:-</span><span class="p">❯</span><span class="si">}}</span>

	prompt_pure_reset_prompt
<span class="o">}</span>

prompt_pure_reset_vim_prompt_widget<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit
	prompt_pure_reset_prompt_symbol

	<span class="c1"># We can't perform a prompt reset at this point because it</span>
	<span class="c1"># removes the prompt marks inserted by macOS Terminal.</span>
<span class="o">}</span>

prompt_pure_state_setup<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	<span class="c1"># Check SSH_CONNECTION and the current state.</span>
	<span class="nb">local</span> <span class="nv">ssh_connection</span><span class="o">=</span><span class="si">${</span><span class="nv">SSH_CONNECTION</span><span class="k">:-</span><span class="nv">$PROMPT_PURE_SSH_CONNECTION</span><span class="si">}</span>
	<span class="nb">local</span> username hostname
	<span class="k">if</span> <span class="o">[[</span> -z <span class="nv">$ssh_connection</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="o">((</span> $+commands<span class="o">[</span>who<span class="o">]</span> <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># When changing user on a remote system, the $SSH_CONNECTION</span>
		<span class="c1"># environment variable can be lost. Attempt detection via `who`.</span>
		<span class="nb">local</span> who_out
		<span class="nv">who_out</span><span class="o">=</span><span class="k">$(</span>who -m <span class="m">2</span>&gt;/dev/null<span class="k">)</span>
		<span class="k">if</span> <span class="o">((</span> <span class="nv">$?</span> <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
			<span class="c1"># Who am I not supported, fallback to plain who.</span>
			<span class="nb">local</span> -a who_in
			<span class="nv">who_in</span><span class="o">=(</span> <span class="si">${</span><span class="p">(f)</span><span class="s2">"</span><span class="k">$(</span>who <span class="m">2</span>&gt;/dev/null<span class="k">)</span><span class="s2">"</span><span class="si">}</span> <span class="o">)</span>
			<span class="nv">who_out</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="p">(M)who_in:#*[[:</span><span class="nv">space</span><span class="p">:]]</span><span class="si">${</span><span class="nv">TTY</span><span class="p">#/dev/</span><span class="si">}</span><span class="p">[[:</span><span class="nv">space</span><span class="p">:]]*</span><span class="si">}</span><span class="s2">"</span>
		<span class="k">fi</span>

		<span class="nb">local</span> <span class="nv">reIPv6</span><span class="o">=</span><span class="s1">'(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+'</span>  <span class="c1"># Simplified, only checks partial pattern.</span>
		<span class="nb">local</span> <span class="nv">reIPv4</span><span class="o">=</span><span class="s1">'([0-9]{1,3}\.){3}[0-9]+'</span>   <span class="c1"># Simplified, allows invalid ranges.</span>
		<span class="c1"># Here we assume two non-consecutive periods represents a</span>
		<span class="c1"># hostname. This matches `foo.bar.baz`, but not `foo.bar`.</span>
		<span class="nb">local</span> <span class="nv">reHostname</span><span class="o">=</span><span class="s1">'([.][^. ]+){2}'</span>

		<span class="c1"># Usually the remote address is surrounded by parenthesis, but</span>
		<span class="c1"># not on all systems (e.g. busybox).</span>
		<span class="nb">local</span> -H MATCH MBEGIN MEND
		<span class="k">if</span> <span class="o">[[</span> <span class="nv">$who_out</span> <span class="o">=</span>~ <span class="s2">"\(?(</span><span class="nv">$reIPv4</span><span class="s2">|</span><span class="nv">$reIPv6</span><span class="s2">|</span><span class="nv">$reHostname</span><span class="s2">)\)?\$"</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
			<span class="nv">ssh_connection</span><span class="o">=</span><span class="nv">$MATCH</span>

			<span class="c1"># Export variable to allow detection propagation inside</span>
			<span class="c1"># shells spawned by this one (e.g. tmux does not always</span>
			<span class="c1"># inherit the same tty, which breaks detection).</span>
			<span class="nb">export</span> <span class="nv">PROMPT_PURE_SSH_CONNECTION</span><span class="o">=</span><span class="nv">$ssh_connection</span>
		<span class="k">fi</span>
		<span class="nb">unset</span> MATCH MBEGIN MEND
	<span class="k">fi</span>

	<span class="nv">hostname</span><span class="o">=</span><span class="s1">'%F{$prompt_pure_colors[host]}@%m%f'</span>
	<span class="c1"># Show `username@host` if logged in through SSH.</span>
	<span class="o">[[</span> -n <span class="nv">$ssh_connection</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="nv">username</span><span class="o">=</span><span class="s1">'%F{$prompt_pure_colors[user]}%n%f'</span><span class="s2">"</span><span class="nv">$hostname</span><span class="s2">"</span>

	<span class="c1"># Show `username@host` if root, with username in default color.</span>
	<span class="o">[[</span> <span class="nv">$UID</span> -eq <span class="m">0</span> <span class="o">]]</span> <span class="o">&amp;&amp;</span> <span class="nv">username</span><span class="o">=</span><span class="s1">'%F{$prompt_pure_colors[user:root]}%n%f'</span><span class="s2">"</span><span class="nv">$hostname</span><span class="s2">"</span>

	<span class="nb">typeset</span> -gA prompt_pure_state
	prompt_pure_state<span class="o">[</span>version<span class="o">]=</span><span class="s2">"1.10.3"</span>
	<span class="nv">prompt_pure_state</span><span class="o">+=(</span>
		username <span class="s2">"</span><span class="nv">$username</span><span class="s2">"</span>
		prompt	 <span class="s2">"</span><span class="si">${</span><span class="nv">PURE_PROMPT_SYMBOL</span><span class="k">:-</span><span class="p">❯</span><span class="si">}</span><span class="s2">"</span>
	<span class="o">)</span>
<span class="o">}</span>

prompt_pure_system_report<span class="o">()</span> <span class="o">{</span>
	setopt localoptions noshwordsplit

	print - <span class="s2">"- Zsh: </span><span class="k">$(</span>zsh --version<span class="k">)</span><span class="s2">"</span>
	print -n - <span class="s2">"- Operating system: "</span>
	<span class="k">case</span> <span class="s2">"</span><span class="k">$(</span>uname -s<span class="k">)</span><span class="s2">"</span> <span class="k">in</span>
		Darwin<span class="o">)</span>	print <span class="s2">"</span><span class="k">$(</span>sw_vers -productName<span class="k">)</span><span class="s2"> </span><span class="k">$(</span>sw_vers -productVersion<span class="k">)</span><span class="s2"> (</span><span class="k">$(</span>sw_vers -buildVersion<span class="k">)</span><span class="s2">)"</span><span class="p">;;</span>
		*<span class="o">)</span>	print <span class="s2">"</span><span class="k">$(</span>uname -s<span class="k">)</span><span class="s2"> (</span><span class="k">$(</span>uname -v<span class="k">)</span><span class="s2">)"</span><span class="p">;;</span>
	<span class="k">esac</span>
	print - <span class="s2">"- Terminal program: </span><span class="nv">$TERM_PROGRAM</span><span class="s2"> (</span><span class="nv">$TERM_PROGRAM_VERSION</span><span class="s2">)"</span>

	<span class="nb">local</span> git_version
	<span class="nv">git_version</span><span class="o">=(</span><span class="k">$(</span>git --version<span class="k">)</span><span class="o">)</span>  <span class="c1"># Remove newlines, if hub is present.</span>
	print - <span class="s2">"- Git: </span><span class="nv">$git_version</span><span class="s2">"</span>

	print - <span class="s2">"- Pure state:"</span>
	<span class="k">for</span> k v <span class="k">in</span> <span class="s2">"</span><span class="si">${</span><span class="p">(@kv)prompt_pure_state</span><span class="si">}</span><span class="s2">"</span><span class="p">;</span> <span class="k">do</span>
		print - <span class="s2">"\t- </span><span class="nv">$k</span><span class="s2">: \`</span><span class="si">${</span><span class="p">(q)v</span><span class="si">}</span><span class="s2">\`"</span>
	<span class="k">done</span>
	print - <span class="s2">"- Virtualenv: \`</span><span class="k">$(</span><span class="nb">typeset</span> -p VIRTUAL_ENV_DISABLE_PROMPT<span class="k">)</span><span class="s2">\`"</span>
	print - <span class="s2">"- Prompt: \`</span><span class="k">$(</span><span class="nb">typeset</span> -p PROMPT<span class="k">)</span><span class="s2">\`"</span>

	<span class="nb">local</span> <span class="nv">ohmyzsh</span><span class="o">=</span><span class="m">0</span>
	<span class="nb">typeset</span> -la frameworks
	<span class="o">((</span> $+ANTIBODY_HOME <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Antibody"</span><span class="o">)</span>
	<span class="o">((</span> $+ADOTDIR <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Antigen"</span><span class="o">)</span>
	<span class="o">((</span> $+ANTIGEN_HS_HOME <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Antigen-hs"</span><span class="o">)</span>
	<span class="o">((</span> $+functions<span class="o">[</span>upgrade_oh_my_zsh<span class="o">]</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="o">{</span>
		<span class="nv">ohmyzsh</span><span class="o">=</span><span class="m">1</span>
		<span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Oh My Zsh"</span><span class="o">)</span>
	<span class="o">}</span>
	<span class="o">((</span> $+ZPREZTODIR <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Prezto"</span><span class="o">)</span>
	<span class="o">((</span> $+ZPLUG_ROOT <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Zplug"</span><span class="o">)</span>
	<span class="o">((</span> $+ZPLGM <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"Zplugin"</span><span class="o">)</span>

	<span class="o">((</span> <span class="nv">$#frameworks</span> <span class="o">==</span> <span class="m">0</span> <span class="o">))</span> <span class="o">&amp;&amp;</span> <span class="nv">frameworks</span><span class="o">+=(</span><span class="s2">"None"</span><span class="o">)</span>
	print - <span class="s2">"- Detected frameworks: </span><span class="si">${</span><span class="p">(j:, :)frameworks</span><span class="si">}</span><span class="s2">"</span>

	<span class="k">if</span> <span class="o">((</span> ohmyzsh <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
		print - <span class="s2">"\t- Oh My Zsh:"</span>
		print - <span class="s2">"\t\t- Plugins: </span><span class="si">${</span><span class="p">(j:, :)plugins</span><span class="si">}</span><span class="s2">"</span>
	<span class="k">fi</span>
<span class="o">}</span>

prompt_pure_setup<span class="o">()</span> <span class="o">{</span>
	<span class="c1"># Prevent percentage showing up if output doesn't end with a newline.</span>
	<span class="nb">export</span> <span class="nv">PROMPT_EOL_MARK</span><span class="o">=</span><span class="s1">''</span>

	<span class="nv">prompt_opts</span><span class="o">=(</span>subst percent<span class="o">)</span>

	<span class="c1"># Borrowed from `promptinit`. Sets the prompt options in case Pure was not</span>
	<span class="c1"># initialized via `promptinit`.</span>
	setopt noprompt<span class="o">{</span>bang,cr,percent,subst<span class="o">}</span> <span class="s2">"prompt</span><span class="si">${</span><span class="p">^prompt_opts[@]</span><span class="si">}</span><span class="s2">"</span>

	<span class="k">if</span> <span class="o">[[</span> -z <span class="nv">$prompt_newline</span> <span class="o">]]</span><span class="p">;</span> <span class="k">then</span>
		<span class="c1"># This variable needs to be set, usually set by promptinit.</span>
		<span class="nb">typeset</span> -g <span class="nv">prompt_newline</span><span class="o">=</span><span class="s1">$'\n%{\r%}'</span>
	<span class="k">fi</span>

	zmodload zsh/datetime
	zmodload zsh/zle
	zmodload zsh/parameter
	zmodload zsh/zutil

	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info
	autoload -Uz async <span class="o">&amp;&amp;</span> async

	<span class="c1"># The `add-zle-hook-widget` function is not guaranteed to be available.</span>
	<span class="c1"># It was added in Zsh 5.3.</span>
	autoload -Uz +X add-zle-hook-widget <span class="m">2</span>&gt;/dev/null

	<span class="c1"># Set the colors.</span>
	<span class="nb">typeset</span> -gA prompt_pure_colors_default prompt_pure_colors
	<span class="nv">prompt_pure_colors_default</span><span class="o">=(</span>
		execution_time       yellow
		git:arrow            cyan
		git:branch           <span class="m">242</span>
		git:branch:cached    red
		host                 <span class="m">242</span>
		path                 blue
		prompt:error         red
		prompt:success       magenta
		user                 <span class="m">242</span>
		user:root            default
		virtualenv           <span class="m">242</span>
	<span class="o">)</span>
	<span class="nv">prompt_pure_colors</span><span class="o">=(</span><span class="s2">"</span><span class="si">${</span><span class="p">(@kv)prompt_pure_colors_default</span><span class="si">}</span><span class="s2">"</span><span class="o">)</span>

	add-zsh-hook precmd prompt_pure_precmd
	add-zsh-hook preexec prompt_pure_preexec

	prompt_pure_state_setup

	zle -N prompt_pure_reset_prompt
	zle -N prompt_pure_update_vim_prompt_widget
	zle -N prompt_pure_reset_vim_prompt_widget
	<span class="k">if</span> <span class="o">((</span> $+functions<span class="o">[</span>add-zle-hook-widget<span class="o">]</span> <span class="o">))</span><span class="p">;</span> <span class="k">then</span>
		add-zle-hook-widget zle-line-finish prompt_pure_reset_vim_prompt_widget
		add-zle-hook-widget zle-keymap-select prompt_pure_update_vim_prompt_widget
	<span class="k">fi</span>

	<span class="c1"># If a virtualenv is activated, display it in grey.</span>
	<span class="nv">PROMPT</span><span class="o">=</span><span class="s1">'%(12V.%F{$prompt_pure_colors[virtualenv]}%12v%f .)'</span>

	<span class="c1"># Prompt turns red if the previous command didn't exit with 0.</span>
	<span class="nv">PROMPT</span><span class="o">+=</span><span class="s1">'%(?.%F{$prompt_pure_colors[prompt:success]}.%F{$prompt_pure_colors[prompt:error]})${prompt_pure_state[prompt]}%f '</span>

	<span class="c1"># Indicate continuation prompt by ... and use a darker color for it.</span>
	<span class="nv">PROMPT2</span><span class="o">=</span><span class="s1">'%F{242}... %(1_.%_ .%_)%f%(?.%F{magenta}.%F{red})${prompt_pure_state[prompt]}%f '</span>

	<span class="c1"># Store prompt expansion symbols for in-place expansion via (%). For</span>
	<span class="c1"># some reason it does not work without storing them in a variable first.</span>
	<span class="nb">typeset</span> -ga prompt_pure_debug_depth
	<span class="nv">prompt_pure_debug_depth</span><span class="o">=(</span><span class="s1">'%e'</span> <span class="s1">'%N'</span> <span class="s1">'%x'</span><span class="o">)</span>

	<span class="c1"># Compare is used to check if %N equals %x. When they differ, the main</span>
	<span class="c1"># prompt is used to allow displaying both filename and function. When</span>
	<span class="c1"># they match, we use the secondary prompt to avoid displaying duplicate</span>
	<span class="c1"># information.</span>
	<span class="nb">local</span> -A ps4_parts
	<span class="nv">ps4_parts</span><span class="o">=(</span>
		depth 	  <span class="s1">'%F{yellow}${(l:${(%)prompt_pure_debug_depth[1]}::+:)}%f'</span>
		compare   <span class="s1">'${${(%)prompt_pure_debug_depth[2]}:#${(%)prompt_pure_debug_depth[3]}}'</span>
		main      <span class="s1">'%F{blue}${${(%)prompt_pure_debug_depth[3]}:t}%f%F{242}:%I%f %F{242}@%f%F{blue}%N%f%F{242}:%i%f'</span>
		secondary <span class="s1">'%F{blue}%N%f%F{242}:%i'</span>
		prompt 	  <span class="s1">'%F{242}&gt;%f '</span>
	<span class="o">)</span>
	<span class="c1"># Combine the parts with conditional logic. First the `:+` operator is</span>
	<span class="c1"># used to replace `compare` either with `main` or an ampty string. Then</span>
	<span class="c1"># the `:-` operator is used so that if `compare` becomes an empty</span>
	<span class="c1"># string, it is replaced with `secondary`.</span>
	<span class="nb">local</span> <span class="nv">ps4_symbols</span><span class="o">=</span><span class="s1">'${${'</span><span class="si">${</span><span class="nv">ps4_parts</span><span class="p">[compare]</span><span class="si">}</span><span class="s1">':+"'</span><span class="si">${</span><span class="nv">ps4_parts</span><span class="p">[main]</span><span class="si">}</span><span class="s1">'"}:-"'</span><span class="si">${</span><span class="nv">ps4_parts</span><span class="p">[secondary]</span><span class="si">}</span><span class="s1">'"}'</span>

	<span class="c1"># Improve the debug prompt (PS4), show depth by repeating the +-sign and</span>
	<span class="c1"># add colors to highlight essential parts like file and function name.</span>
	<span class="nv">PROMPT4</span><span class="o">=</span><span class="s2">"</span><span class="si">${</span><span class="nv">ps4_parts</span><span class="p">[depth]</span><span class="si">}</span><span class="s2"> </span><span class="si">${</span><span class="nv">ps4_symbols</span><span class="si">}${</span><span class="nv">ps4_parts</span><span class="p">[prompt]</span><span class="si">}</span><span class="s2">"</span>

	<span class="c1"># Guard against Oh My Zsh themes overriding Pure.</span>
	<span class="nb">unset</span> ZSH_THEME
<span class="o">}</span>

prompt_pure_setup <span class="s2">"</span><span class="nv">$@</span><span class="s2">"</span>
</pre></div>
</div>
</div>
<script src="/static/linelight.js"></script>
</div></body>
</html>