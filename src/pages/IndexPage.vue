<template>
  <q-page class="q-pa-md">
    <div class="text-h4 q-mb-md text-primary">
      แผนที่แสดงข้อมูลราคายำไย (Longan Price Map)
    </div>

    <q-form @submit.prevent="addMarkerFromForm" class="q-gutter-md q-mb-md bg-grey-2 p-4 rounded-lg shadow-md">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
        <q-input outlined v-model="form.provincePlace" label="ชื่อสถานที่/จังหวัด" required />
        <q-input outlined v-model.number="form.price" label="ราคา (บาท/กก.)" type="number" step="0.01" required />
        <q-input outlined v-model="form.date" label="วันที่สำรวจ" type="date" required />
        
        <div class="flex space-x-2">
          <q-input outlined v-model.number="form.lat" label="Latitude (ไม่บังคับ)" type="number" step="0.000001" style="width: 50%;" />
          <q-input outlined v-model.number="form.lng" label="Longitude (ไม่บังคับ)" type="number" step="0.000001" style="width: 50%;" />
        </div>
      </div>
      <q-btn label="เพิ่มจุดใหม่" type="submit" color="primary" class="w-full" />
    </q-form>

    <div id="map" class="map-container q-mb-xl" :class="tailwindClasses"></div>

    <div class="text-h5 q-mb-md text-secondary">
      รายการข้อมูลราคายำไยที่บันทึกไว้ ({{ markersData.length }} จุด)
    </div>

    <q-table
      :rows="markersData"
      :columns="columns"
      row-key="provincePlace"
      flat bordered
      separator="cell"
      class="shadow-md"
    >
      </q-table>
  </q-page>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue';
import * as L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useQuasar } from 'quasar';


delete L.Icon.Default.prototype._getIconUrl; 

L.Icon.Default.mergeOptions({
  
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
});

const greenIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png', 
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const $q = useQuasar();
const map = ref(null);
const markersData = ref([]); 
const markersLayer = ref(L.featureGroup()); 
const form = ref({
  provincePlace: '',
  price: null,
  date: new Date().toISOString().slice(0, 10),
  lat: null,
  lng: null,
});

// ✅ คอลัมน์สำหรับ Q-Table: ลบคอลัมน์ 'actions' ออก
const columns = [
  { name: 'provincePlace', align: 'left', label: 'สถานที่/จังหวัด', field: 'provincePlace', sortable: true },
  { name: 'price', align: 'right', label: 'ราคา (บาท/กก.)', field: 'price', format: val => val ? val.toFixed(2) : 'N/A', sortable: true },
  { name: 'date', align: 'center', label: 'วันที่สำรวจ', field: 'date', sortable: true },
  { name: 'lat', align: 'right', label: 'Lat', field: 'lat', format: val => val ? val.toFixed(4) : 'N/A' },
  { name: 'lng', align: 'right', label: 'Lng', field: 'lng', format: val => val ? val.toFixed(4) : 'N/A' },
];


const initialData = [
  { provincePlace: "เชียงใหม่", price: 35.50, date: "2023-08-15", lat: 18.7883, lng: 98.9853 },
  { provincePlace: "ตลาดสันทราย-เชียงใหม่", price: 38.00, date: "2023-08-16", lat: 18.8056, lng: 99.0105 },
  { provincePlace: "ลำพูน", price: 34.00, date: "2023-08-15", lat: 18.5833, lng: 99.0000 },
];


const getCachedCoordinates = (address) => {
    const cached = localStorage.getItem(`geocode_cache_${address}`);
    return cached ? JSON.parse(cached) : null;
};

const setCachedCoordinates = (address, coords) => {
    localStorage.setItem(`geocode_cache_${address}`, JSON.stringify(coords));
};

const STORAGE_KEY = 'longan_map_markers';

const loadMarkersFromStorage = () => {
    const cachedData = localStorage.getItem(STORAGE_KEY);
    if (cachedData) {
        try {
            markersData.value = JSON.parse(cachedData);
        } catch (e) {
            console.error("Error parsing marker data from storage:", e);
            markersData.value = initialData;
        }
    } else {
        markersData.value = initialData;
        saveMarkersToStorage(); 
    }
};

const saveMarkersToStorage = () => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(markersData.value));
};

// --------------------------------------------------------------------------
// ✅ ลบฟังก์ชัน deleteMarker และ confirmDelete ออกทั้งหมด
// --------------------------------------------------------------------------


const initializeMap = () => {
  
  const northernThailandCenter = [18.2917, 99.4589]; 
  const initialZoom = 8; 

  map.value = L.map('map').setView(northernThailandCenter, initialZoom);

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
  }).addTo(map.value);
  
  
  markersLayer.value.addTo(map.value);
};


const addMarker = (data) => {
  const marker = L.marker([data.lat, data.lng], { icon: greenIcon })
    .bindPopup(`
      <div class="p-1">
        <p class="font-bold text-lg mb-0">${data.provincePlace}</p>
        <p class="mb-0">ราคา: <span class="text-green-600 font-semibold">${data.price.toFixed(2)} บาท/กก.</span></p>
        <p class="mb-0">วันที่: ${data.date}</p>
      </div>
    `);
    
  markersLayer.value.addLayer(marker);
};


const fitMapToBounds = () => {
  if (markersLayer.value.getLayers().length > 0) {
    map.value.fitBounds(markersLayer.value.getBounds(), { padding: [50, 50] });
  }
};

const renderMarkers = () => {
  markersLayer.value.clearLayers();
  markersData.value.forEach(addMarker);
  
  fitMapToBounds();
};


const geocodeAddress = async (address) => {
  
  const cachedCoord = getCachedCoordinates(address);
  if (cachedCoord) {
    console.log('พิกัดจาก Local Storage');
    return cachedCoord;
  }
  
  
  const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}&countrycodes=th&limit=1`;
  try {
    const response = await fetch(url);
    const data = await response.json();
    
    if (data && data.length > 0) {
      const lat = parseFloat(data[0].lat);
      const lng = parseFloat(data[0].lon);
      const coords = { lat, lng };
      
      
      setCachedCoordinates(address, coords);
      return coords;
    }
  } catch (error) {
    console.error('Geocoding Error:', error);
    $q.notify({ type: 'negative', message: 'ไม่สามารถแปลงชื่อสถานที่ให้เป็นพิกัดได้' });
  }
  return null;
};



const addMarkerFromForm = async () => {
  const newMarkerData = { ...form.value };
  
  
  let coords = { lat: null, lng: null };


  if (!newMarkerData.provincePlace || !newMarkerData.price || !newMarkerData.date) {
      $q.notify({ type: 'negative', message: 'กรุณากรอก ชื่อสถานที่, ราคา, และ วันที่ ให้ครบถ้วน' });
      return;
  }
  

  const inputLat = parseFloat(newMarkerData.lat);
  const inputLng = parseFloat(newMarkerData.lng);

  if (!isNaN(inputLat) && !isNaN(inputLng)) {
      
      coords.lat = inputLat;
      coords.lng = inputLng;
      console.log('ใช้พิกัดที่ผู้ใช้ป้อนเอง:', coords.lat, coords.lng);
  } else {
      
      $q.notify({ type: 'info', message: `กำลังค้นหาพิกัด Geocoding สำหรับ "${newMarkerData.provincePlace}"...` });
      coords = await geocodeAddress(`${newMarkerData.provincePlace}, ภาคเหนือ, ประเทศไทย`);
      
      if (!coords) {
        $q.notify({ type: 'warning', message: 'ไม่พบพิกัดสำหรับสถานที่นี้ กรุณาลองกรอกพิกัดเอง' });
        return;
      }
      console.log('ใช้พิกัด Geocoding:', coords.lat, coords.lng);
  }
  

  const markerFinalData = {
    provincePlace: newMarkerData.provincePlace,
    price: parseFloat(newMarkerData.price),
    date: newMarkerData.date,
    lat: coords.lat, 
    lng: coords.lng, 
  };
  
  
  if (isNaN(markerFinalData.lat) || isNaN(markerFinalData.lng)) {
      $q.notify({ type: 'negative', message: 'ข้อผิดพลาดภายใน: พิกัดไม่สามารถแปลงเป็นตัวเลขได้ กรุณาตรวจสอบข้อมูล' });
      return;
  }
  
  markersData.value.push(markerFinalData);
  addMarker(markerFinalData);
  fitMapToBounds(); 
  
  saveMarkersToStorage(); 
  
  
  form.value = { provincePlace: '', price: null, date: new Date().toISOString().slice(0, 10), lat: null, lng: null };

  $q.notify({ type: 'positive', message: `เพิ่มจุด "${markerFinalData.provincePlace}" เรียบร้อยแล้ว` });
};



onMounted(() => {
  
  nextTick(() => {
    initializeMap();
    
    loadMarkersFromStorage();
    
    renderMarkers(); 
  });
});
</script>

<style scoped>

.map-container {
  height: 600px;
  width: 100%;
}
.tailwindClasses {
  
  @apply rounded-xl shadow-2xl border-4 border-gray-100;
}
</style>