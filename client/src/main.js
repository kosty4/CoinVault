import Vue from 'vue'
import App from './App.vue'
import store from './store'
import vuetify from './plugins/vuetify'
// import web3plugin from "./plugins/web3plugin";

Vue.config.productionTip = false
// Vue.use(web3plugin)

new Vue({
  store,
  vuetify,
  // web3plugin,
  render: h => h(App)
}).$mount('#app')
