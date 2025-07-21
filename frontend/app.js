const simpleSwapAddress = "0x622f1970336c01a34Dd7d4c5374bFFB6Bb526964";
const tokenA = "0x5F8262Eab3357BdEB54d416ccbF025Cbe220EB28";
const tokenB = "0xb2587cf3af483e8c2448b7922b7691b2aff8b09b";

let simpleSwapABI;
const erc20ABI = [
  {
    "constant": false,
    "inputs": [
      { "name": "spender", "type": "address" },
      { "name": "value", "type": "uint256" }
    ],
    "name": "approve",
    "outputs": [{ "name": "", "type": "bool" }],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{ "name": "owner", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "name": "", "type": "uint256" }],
    "type": "function"
  }
];

let web3;
let account;
let simpleSwap;

async function loadABI() {
  const response = await fetch("simpleswap-abi.json");
  simpleSwapABI = await response.json();
}

async function connectWallet() {
  if (window.ethereum) {
    await loadABI();
    web3 = new Web3(window.ethereum);
    await window.ethereum.request({ method: "eth_requestAccounts" });
    const accounts = await web3.eth.getAccounts();
    account = accounts[0];
    document.getElementById("account").innerText = account;
    simpleSwap = new web3.eth.Contract(simpleSwapABI, simpleSwapAddress);
  } else {
    alert("Please install MetaMask");
  }
}

function disconnectWallet() {
  account = null;
  document.getElementById("account").innerText = "Not connected";
}

async function approve() {
  const amount = web3.utils.toWei("10000", "ether");
  const token = new web3.eth.Contract(erc20ABI, tokenA);
  await token.methods.approve(simpleSwapAddress, amount).send({ from: account });
  alert("Approved successfully");
}

async function swap() {
  if (!web3 || !simpleSwap) return;

  const input = document.getElementById("amountIn").value;
  if (!input || isNaN(input)) {
    alert("Invalid input amount");
    return;
  }

  const amountIn = BigInt(web3.utils.toWei(input, "ether"));
  const deadline = Math.floor(Date.now() / 1000) + 300;
  const path = [tokenA, tokenB];

  try {
    const price = await simpleSwap.methods.getPrice(tokenA, tokenB).call();
    const priceBN = BigInt(price);

    // Estimate output and apply 1% slippage tolerance
    const estimatedOut = (amountIn * priceBN) / BigInt(1e18);
    const amountOutMin = (estimatedOut * 95n) / 100n;


    await simpleSwap.methods.swapExactTokensForTokens(
      amountIn.toString(),
      amountOutMin.toString(),
      path,
      account,
      deadline
    ).send({ from: account });

    alert("Swap completed");
  } catch (error) {
    console.error("Swap failed:", error);
    alert("Swap failed: " + (error?.message || "unknown error"));
  }
}

async function calculateAmountOut() {
  if (!web3 || !simpleSwap) return;

  const input = document.getElementById("amountIn").value;
  if (!input || isNaN(input)) return;

  try {
    const amountIn = BigInt(web3.utils.toWei(input, "ether"));
    const price = await simpleSwap.methods.getPrice(tokenA, tokenB).call();
    const priceBN = BigInt(price);

    const estimatedOut = (amountIn * priceBN) / BigInt(1e18);
    const formattedOut = web3.utils.fromWei(estimatedOut.toString(), "ether");

    document.getElementById("amountOutMin").value = formattedOut;
  } catch (error) {
    console.error("Error estimating output amount:", error);
    document.getElementById("amountOutMin").value = "Error";
  }
}
