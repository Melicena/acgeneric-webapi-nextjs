import SearchOffers from "./components/SearchOffers";
import Image from "next/image";

export default function Home() {
  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-black">
      <main className="container mx-auto py-12 px-4">
        <div className="flex flex-col items-center mb-12">
          <Image
            className="dark:invert mb-8"
            src="/next.svg"
            alt="Next.js logo"
            width={180}
            height={37}
            priority
          />
          <h1 className="text-4xl font-bold text-center text-gray-900 dark:text-white mb-4">
            Buscador de Ofertas
          </h1>
          <p className="text-lg text-gray-600 dark:text-gray-400 text-center max-w-2xl">
            Encuentra las mejores ofertas cerca de ti. Busca por nombre del comercio o título de la oferta.
          </p>
        </div>
        
        <SearchOffers />
      </main>
    </div>
  );
}
