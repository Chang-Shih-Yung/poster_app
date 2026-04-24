import Nav from "@/components/Nav";
import WorkForm from "./WorkForm";

export default function NewWorkPage() {
  return (
    <>
      <Nav />
      <main className="px-6 py-8 max-w-2xl mx-auto">
        <h1 className="text-2xl font-semibold mb-6">新增作品</h1>
        <WorkForm mode="create" />
      </main>
    </>
  );
}
