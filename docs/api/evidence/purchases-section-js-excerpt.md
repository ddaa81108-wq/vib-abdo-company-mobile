# PurchasesSection JS excerpt

Fetched `2026-10-23T07:56:03Z` from `https://staging.vip2100.com/assets/PurchasesSection-BvxICuQj.js`.

- HTTP 200
- `content-type: text/javascript; charset=utf-8`
- `content-length: 19381`
- `last-modified: Fri, 23 Oct 2026 05:54:22 GMT`
- sha256 `1fb6883ffc4d8e2941d6f5811c90f767ff5769b4fae6843267640f3117e61191`

The snippets below are contiguous slices of that file. They are not rewritten.

This file does not contain `الباقي الحالي وباقي فودافون كاش الحالي رصيد متراكم لليوم المفتوح، وليس مجموع البطاقات.`

## Grid header

```javascript
function pe(){return a.jsxs("div",{className:"purchase-grid purchase-grid-head",children:[a.jsx("span",{children:s("التسلسل")}),a.jsx("span",{children:s("النوع")}),a.jsx("span",{children:s("القيمة ج.م")}),a.jsx("span",{children:s("العملية")}),a.jsx("span",{children:s("السعر")}),a.jsx("span",{children:s("الناتج")}),a.jsx("span",{children:s("المسدد")}),a.jsx("span",{children:s("الباقي")}),a.jsx("span",{children:s("مستهلك فودافون")}),a.jsx("span",{children:s("الإجراءات")})]})}
```

## Day bar, including the Vodafone sign

```javascript
function me({day:e}){return a.jsxs("div",{className:"purchase-metrics",children:[a.jsxs("article",{className:e.previousDebtUnits>0?"positive liability":e.previousDebtUnits<0?"negative credit":"zero",children:[a.jsx("span",{children:s("القيمة السابقة")}),a.jsxs("b",{dir:"ltr",children:[v.format(e.previousDebtUnits)," ",s(" د.ل")]})]}),a.jsxs("article",{children:[a.jsx("span",{children:s("إجمالي شغل اليوم")}),a.jsxs("b",{dir:"ltr",children:[v.format(e.todayResultUnits)," ",s(" د.ل")]})]}),a.jsxs("article",{children:[a.jsx("span",{children:s("إجمالي المسدد")}),a.jsxs("b",{dir:"ltr",children:[v.format(e.todayPaidUnits)," ",s(" د.ل")]})]}),a.jsxs("article",{className:e.totalDebtUnits>0?"positive liability":e.totalDebtUnits<0?"negative credit":"zero",children:[a.jsx("span",{children:s("إجمالي الديون")}),a.jsxs("b",{dir:"ltr",children:[v.format(e.totalDebtUnits)," ",s(" د.ل")]})]}),a.jsxs("article",{className:`vodafone ${e.vodafoneRemainingUnits>0?"credit":e.vodafoneRemainingUnits<0?"liability":"zero"}`,children:[a.jsx("span",{children:e.vodafoneRemainingUnits>0?s("باقي فودافون لصالحنا"):e.vodafoneRemainingUnits<0?s("استهلاك فودافون علينا"):s("باقي فودافون كاش")}),a.jsxs("b",{dir:"ltr",children:[v.format(Math.abs(e.vodafoneRemainingUnits))," ",s(" ج.م")]})]})]})}
```

## Register totals

```javascript
function xe({totals:e}){return a.jsxs(a.Fragment,{children:[a.jsxs("div",{className:"purchase-grid purchase-register-total purchase-register-grand-total",children:[a.jsx("strong",{children:s("إجماليات السجل من البداية")}),a.jsx("span",{className:"purchase-total-result","data-label":s("إجمالي الناتج"),children:v.format(e.resultUnits)}),a.jsx("span",{className:"purchase-total-paid","data-label":s("إجمالي المسدد"),children:v.format(e.paidUnits)}),a.jsx("span",{className:`purchase-total-remaining ${e.remainingUnits>0?"liability":e.remainingUnits<0?"credit":"zero"}`,"data-label":s("الباقي الحالي"),children:v.format(e.remainingUnits)}),a.jsx("span",{className:"purchase-total-consumed","data-label":s("إجمالي مستهلك فودافون"),children:v.format(e.vodafoneConsumedUnits)})]}),a.jsxs("div",{className:"purchase-grid purchase-register-total purchase-vodafone-total",children:[a.jsx("strong",{children:s("باقي فودافون كاش الحالي")}),a.jsx("span",{className:"purchase-total-consumed","data-label":s("باقي فودافون كاش"),children:v.format(e.vodafoneRemainingUnits)})]})]})}
```

## Opening fields

```javascript
a.jsxs("div",{className:"purchase-opening",children:[a.jsx("strong",{children:s("ضبط البداية لأول تشغيل فقط")}),a.jsxs("label",{children:[s("القيمة السابقة"),a.jsx("input",{dir:"ltr",inputMode:"numeric",value:c,onChange:g=>o(g.target.value.replace(/[^0-9-]/g,""))})]}),a.jsxs("label",{children:[s("فودافون المرحّل"),a.jsx("input",{dir:"ltr",inputMode:"numeric",value:l,onChange:g=>u(g.target.value.replace(/[^0-9-]/g,""))})]}),a.jsx("button",{disabled:b,onClick:()=>{h()},children:s("حفظ البداية")})]})}
```
