<template>
  <div class="admin-table">
    <div class="admin-table-scroll">
      <slot />
    </div>
  </div>
</template>

<style scoped>
.admin-table {
  width: 100%;
  overflow: hidden;
  border: 1px solid #dce9dc;
  border-radius: 14px;
  background: #fff;
  box-shadow: 0 8px 24px #1645230b;
}
.admin-table-scroll { width: 100%; overflow-x: auto; }
.admin-table :deep(table) {
  width: 100%;
  min-width: 680px;
  border-collapse: collapse;
  background: #fff;
  color: #29432f;
  text-align: left;
}
.admin-table :deep(th) {
  padding: 13px 15px;
  border-bottom: 1px solid #e3eee2;
  background: #f4faf3;
  color: #607763;
  font-size: 10px;
  font-weight: 750;
  letter-spacing: .045em;
  text-transform: uppercase;
  white-space: nowrap;
}
.admin-table :deep(td) {
  padding: 14px 15px;
  border-bottom: 1px solid #e9f0e8;
  color: #405845;
  font-size: 12px;
  vertical-align: middle;
}
.admin-table :deep(tbody tr:last-child td) { border-bottom: 0; }
.admin-table :deep(tbody tr:hover td) { background: #f7fbf6; }
@media (max-width: 700px) {
  .admin-table :deep(table) { min-width: 620px; }
}
</style>
