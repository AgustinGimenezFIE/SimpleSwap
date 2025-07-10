const simpleSwapAddress = "0x024d1e8c738db213c55fde6fda46bca8c8a8e98a";
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
    await loadABI(); // 🔁 Cargar ABI antes de usarlo
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
  const amountIn = web3.utils.toWei(document.getElementById("amountIn").value, "ether");
  const amountOutMin = web3.utils.toWei(document.getElementById("amountOutMin").value, "ether");
  const deadline = Math.floor(Date.now() / 1000) + 300;
  const path = [tokenA, tokenB];

  await simpleSwap.methods.swapExactTokensForTokens(
    amountIn, amountOutMin, path, account, deadline
  ).send({ from: account });

  alert("Swap completed");
}

async function calculateAmountOut() {
  if (!web3 || !simpleSwap) return;

  const input = document.getElementById("amountIn").value;
  if (!input) return;

  const amountIn = web3.utils.toWei(input, "ether");

  const key = await simpleSwap.methods.getPrice(tokenA, tokenB).call();
  const reserveA = await simpleSwap.methods.getAmountOut(amountIn, 1e18, key).call(); // Simulación

  const amountOut = web3.utils.fromWei(reserveA, "ether");
  document.getElementById("amountOutMin").value = amountOut;
}
