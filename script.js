const display = document.querySelector("#display");
const keypad = document.querySelector(".keypad");

let currentValue = "0";
let storedValue = null;
let pendingOperator = null;
let shouldResetDisplay = false;
let hasError = false;

function updateDisplay() {
  display.textContent = currentValue;
  display.classList.toggle("display--error", hasError);
}

function clearCalculator() {
  currentValue = "0";
  storedValue = null;
  pendingOperator = null;
  shouldResetDisplay = false;
  hasError = false;
  updateDisplay();
}

function inputNumber(number) {
  if (hasError || shouldResetDisplay) {
    currentValue = number;
    shouldResetDisplay = false;
    hasError = false;
  } else if (currentValue === "0") {
    currentValue = number;
  } else if (currentValue.length < 15) {
    currentValue += number;
  }
  updateDisplay();
}

function inputDecimal() {
  if (hasError || shouldResetDisplay) {
    currentValue = "0.";
    shouldResetDisplay = false;
    hasError = false;
  } else if (!currentValue.includes(".")) {
    currentValue += ".";
  }
  updateDisplay();
}

function calculate(left, right, operator) {
  switch (operator) {
    case "+": return left + right;
    case "-": return left - right;
    case "*": return left * right;
    case "/": return right === 0 ? null : left / right;
    default: return right;
  }
}

function showResult(value) {
  if (value === null || !Number.isFinite(value)) {
    currentValue = "Cannot divide by zero";
    hasError = true;
  } else {
    currentValue = Number.parseFloat(value.toPrecision(12)).toString();
    hasError = false;
  }
  updateDisplay();
}

function chooseOperator(operator) {
  if (hasError) return;

  const inputValue = Number(currentValue);
  if (pendingOperator && !shouldResetDisplay) {
    const result = calculate(storedValue, inputValue, pendingOperator);
    showResult(result);
    if (hasError) {
      storedValue = null;
      pendingOperator = null;
      return;
    }
    storedValue = Number(currentValue);
  } else {
    storedValue = inputValue;
  }

  pendingOperator = operator;
  shouldResetDisplay = true;
}

function equals() {
  if (hasError || pendingOperator === null || shouldResetDisplay) return;

  const result = calculate(storedValue, Number(currentValue), pendingOperator);
  showResult(result);
  storedValue = null;
  pendingOperator = null;
  shouldResetDisplay = true;
}

function deleteLast() {
  if (hasError) {
    clearCalculator();
    return;
  }
  if (shouldResetDisplay) return;
  currentValue = currentValue.length > 1 ? currentValue.slice(0, -1) : "0";
  updateDisplay();
}

function handleButton(button) {
  if (button.dataset.number !== undefined) inputNumber(button.dataset.number);
  if (button.dataset.operator) chooseOperator(button.dataset.operator);
  if (button.dataset.action === "decimal") inputDecimal();
  if (button.dataset.action === "clear") clearCalculator();
  if (button.dataset.action === "delete") deleteLast();
  if (button.dataset.action === "equals") equals();
}

keypad.addEventListener("click", (event) => {
  const button = event.target.closest("button");
  if (button) handleButton(button);
});

document.addEventListener("keydown", (event) => {
  const keyMap = {
    Enter: '[data-action="equals"]',
    "=": '[data-action="equals"]',
    Escape: '[data-action="clear"]',
    Backspace: '[data-action="delete"]',
    ".": '[data-action="decimal"]',
    ",": '[data-action="decimal"]'
  };

  let selector = keyMap[event.key];
  if (/^[0-9]$/.test(event.key)) selector = `[data-number="${event.key}"]`;
  if (["+", "-", "*", "/"].includes(event.key)) selector = `[data-operator="${event.key}"]`;

  const button = selector ? document.querySelector(selector) : null;
  if (!button) return;

  event.preventDefault();
  handleButton(button);
  button.classList.add("is-pressed");
  window.setTimeout(() => button.classList.remove("is-pressed"), 100);
});
