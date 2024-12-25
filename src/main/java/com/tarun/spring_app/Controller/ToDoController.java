package com.tarun.spring_app.Controller;
import com.tarun.spring_app.Entity.ToDo;
import com.tarun.spring_app.Repository.ToDoRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;


@RestController
@RequestMapping("/api/todos")
public class ToDoController {

    private final ToDoRepository repository;

    @GetMapping("/test")
    public String testEndpoint() {
        return "Application is working!";
    }

    public ToDoController(ToDoRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<ToDo> getAllTodos() {
        return repository.findAll();
    }

    @PostMapping
    public ToDo createNewTodo(@RequestBody ToDo todo) {
        return repository.save(todo);
    }

    @PutMapping("/{id}")
    public ToDo updateTodo(@PathVariable Long id, @RequestBody ToDo todo) {
        return repository.findById(id)
                .map(existing -> {
                    existing.setTitle(todo.getTitle());
                    existing.setCompleted(todo.isCompleted());
                    return repository.save(existing);
                })
                .orElseThrow(() -> new RuntimeException("Todo not found"));
    }

    @DeleteMapping("/{id}")
    public void deleteTodo(@PathVariable Long id) {
        repository.deleteById(id);
    }
}
